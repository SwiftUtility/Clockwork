import Foundation
import Facility
import FacilityPure
public final class Decorator {
  let execute: Try.Reply<Execute>
  let resolveProfile: Try.Reply<Configuration.ResolveProfile>
  let resolveAwardApproval: Try.Reply<Configuration.ResolveAwardApproval>
  let resolveUserActivity: Try.Reply<Configuration.ResolveUserActivity>
  let resolveCodeOwnage: Try.Reply<Configuration.ResolveCodeOwnage>
  let persistUserActivity: Try.Reply<Configuration.PersistUserActivity>
  let resolveFusion: Try.Reply<Configuration.ResolveFusion>
  let report: Try.Reply<Report>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveProfile: @escaping Try.Reply<Configuration.ResolveProfile>,
    resolveAwardApproval: @escaping Try.Reply<Configuration.ResolveAwardApproval>,
    resolveUserActivity: @escaping Try.Reply<Configuration.ResolveUserActivity>,
    resolveCodeOwnage: @escaping Try.Reply<Configuration.ResolveCodeOwnage>,
    persistUserActivity: @escaping Try.Reply<Configuration.PersistUserActivity>,
    resolveFusion: @escaping Try.Reply<Configuration.ResolveFusion>,
    report: @escaping Try.Reply<Report>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.resolveProfile = resolveProfile
    self.resolveAwardApproval = resolveAwardApproval
    self.resolveUserActivity = resolveUserActivity
    self.resolveCodeOwnage = resolveCodeOwnage
    self.persistUserActivity = persistUserActivity
    self.resolveFusion = resolveFusion
    self.report = report
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func updateUser(cfg: Configuration, active: Bool) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let awardApproval = try resolveAwardApproval(.init(cfg: cfg))
    try persistUserActivity(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      awardApproval: awardApproval,
      userActivity: resolveUserActivity(.init(
        cfg: cfg,
        awardApproval: awardApproval
      )),
      user: gitlabCi.job.user.username,
      active: active
    ))
    return true
  }
  public func checkAwardApproval(cfg: Configuration, mode: AwardApproval.Mode) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let review = try gitlabCi.getParentMrState
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    let pipeline = try gitlabCi.parent.pipeline
      .flatMap(gitlabCi.getPipeline(pipeline:))
      .map(execute)
      .reduce(Json.GitlabPipeline.self, jsonDecoder.decode(success:reply:))
      .get()
    guard pipeline.id == review.pipeline.id, review.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    guard gitlabCi.job.pipeline.ref == review.targetBranch else {
      logMessage(.init(message: "Target branch changed"))
      try gitlabCi.postParentMrPipelines
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
      return false
    }
    var approval = try resolveAwardApproval(.init(cfg: cfg))
    try approval.consider(activeUsers: resolveUserActivity(.init(
      cfg: cfg,
      awardApproval: approval
    )))
    approval.consider(gitlab: gitlabCi)
    approval.consider(review: review)
    let sha = try Id(review.pipeline.sha)
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let profile = try resolveProfile(.init(git: cfg.git, file: .init(
      ref: sha,
      path: gitlabCi.parent.profile.get()
    )))
    var changedFiles: [String] = []
    var merge: Fusion.Merge? = nil
    switch mode {
    case .resolution:
      changedFiles = try Id(review.targetBranch)
        .map(Git.Branch.init(name:))
        .map(Git.Ref.make(remote:))
        .reduce(sha, cfg.git.listChangedFiles(source:target:))
        .map(execute)
        .map(Execute.parseLines(reply:))
        .get()
    case .replication:
      merge = try Lossy(.init(cfg: cfg))
        .map(resolveFusion)
        .flatMap(\.replication)
        .get()
        .makeMerge(supply: review.sourceBranch)
    case .integration:
      merge = try Lossy(.init(cfg: cfg))
        .map(resolveFusion)
        .flatMap(\.integration)
        .get()
        .makeMerge(supply: review.sourceBranch)
    }
    if let merge = merge {
      try approval.consider(participants: resolveParticipants(
        cfg: cfg,
        gitlabCi: gitlabCi,
        merge: merge
      ))
      changedFiles = try resolveChanges(
        git: cfg.git,
        gitlabCi: gitlabCi,
        merge: try Lossy(.init(cfg: cfg))
          .map(resolveFusion)
          .flatMap(\.replication)
          .get()
          .makeMerge(supply: review.sourceBranch),
        review: review,
        pipeline: pipeline
      )
    }
    try approval.consider(
      sanityFiles: profile.sanityFiles + [gitlabCi.config],
      fileApproval: resolveCodeOwnage(.init(cfg: cfg, profile: profile)),
      changedFiles: changedFiles
    )
    let awards = try gitlabCi.getParentMrAwarders
      .map(execute)
      .reduce([Json.GitlabAward].self, jsonDecoder.decode(success:reply:))
      .get()
    try approval.consider(awards: awards)
    for award in approval.state.unhighlighted {
      try gitlabCi
        .postParentMrAward(award: award)
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
    }
    if let reports = try approval.makeNewApprovals(cfg: cfg, review: review) {
      try reports.forEach(report)
      try gitlabCi
        .putMrState(parameters: .init(
          addLabels: approval.state.unnotified
            .joined(separator: ","),
          removeLabels: Set(approval.allGroups.keys)
            .subtracting(approval.state.involved)
            .joined(separator: ",")
        ))
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
    }
    if let unapprovedGroups = try approval.makeUnapprovedGroups() {
      unapprovedGroups.forEach { logMessage(.init(message: "\($0) unapproved")) }
      return false
    }
    if let holders = try approval.makeHoldersReport(cfg: cfg, review: review) {
      try report(holders)
      return false
    }
    return true
  }
  func resolveChanges(
    git: Git,
    gitlabCi: GitlabCi,
    merge: Fusion.Merge,
    review: Json.GitlabReviewState,
    pipeline: Json.GitlabPipeline
  ) throws -> [String] {
    guard review.targetBranch == merge.target.name else { throw Thrown("Wrong target branch name") }
    guard pipeline.user.username != gitlabCi.botLogin else { return [] }
    let initial = try Id(.head)
      .map(git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let sha = try Git.Ref.make(sha: .init(value: pipeline.sha))
    try Id
      .make(git.mergeBase(.make(remote: merge.target), sha))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .map(git.detach(ref:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try Execute.checkStatus(reply: try execute(git.clean))
    try Execute.checkStatus(reply: execute(git.merge(
      ref: .make(sha: merge.fork),
      message: nil,
      noFf: true,
      env: [:],
      escalate: false
    )))
    try Execute.checkStatus(reply: execute(git.quitMerge))
    try Execute.checkStatus(reply: execute(git.addAll))
    try Execute.checkStatus(reply: execute(git.resetSoft(ref: sha)))
    try Execute.checkStatus(reply: execute(git.addAll))
    let result = try Id(git.listLocalChanges)
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
    try Execute.checkStatus(reply: execute(git.resetHard(ref: initial)))
    try Execute.checkStatus(reply: execute(git.clean))
    return result
  }
  func resolveParticipants(
    cfg: Configuration,
    gitlabCi: GitlabCi,
    merge: Fusion.Merge
  ) throws -> [String] { try Id
    .make(cfg.git.listCommits(
      in: [.make(sha: merge.fork)],
      notIn: [.make(remote: merge.target)],
      noMerges: true,
      firstParents: false
    ))
    .map(execute)
    .map(Execute.parseLines(reply:))
    .get()
    .map(Git.Sha.init(value:))
    .flatMap { sha in try gitlabCi
      .listShaMergeRequests(sha: sha)
      .map(execute)
      .reduce([Json.GitlabCommitMergeRequest].self, jsonDecoder.decode(success:reply:))
      .get()
      .filter { $0.squashCommitSha == sha.value }
      .map(\.author.username)
    }
  }
}
