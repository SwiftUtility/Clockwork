import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabAwardApprover {
  let execute: Try.Reply<Execute>
  let resolveProfile: Try.Reply<ResolveProfile>
  let resolveAwardApproval: Try.Reply<ResolveAwardApproval>
  let resolveAwardApprovalUserActivity: Try.Reply<ResolveAwardApprovalUserActivity>
  let resolveCodeOwnage: Try.Reply<ResolveCodeOwnage>
  let persistUserActivity: Try.Reply<PersistUserActivity>
  let resolveFlow: Try.Reply<ResolveFlow>
  let sendReport: Try.Reply<SendReport>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveProfile: @escaping Try.Reply<ResolveProfile>,
    resolveAwardApproval: @escaping Try.Reply<ResolveAwardApproval>,
    resolveAwardApprovalUserActivity: @escaping Try.Reply<ResolveAwardApprovalUserActivity>,
    resolveCodeOwnage: @escaping Try.Reply<ResolveCodeOwnage>,
    persistUserActivity: @escaping Try.Reply<PersistUserActivity>,
    resolveFlow: @escaping Try.Reply<ResolveFlow>,
    sendReport: @escaping Try.Reply<SendReport>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.resolveProfile = resolveProfile
    self.resolveAwardApproval = resolveAwardApproval
    self.resolveAwardApprovalUserActivity = resolveAwardApprovalUserActivity
    self.resolveCodeOwnage = resolveCodeOwnage
    self.persistUserActivity = persistUserActivity
    self.resolveFlow = resolveFlow
    self.sendReport = sendReport
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func updateUser(cfg: Configuration, active: Bool) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(_:from:))
      .get()
    let awardApproval = try resolveAwardApproval(.init(cfg: cfg))
    _ = try persistUserActivity(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      awardApproval: awardApproval,
      userActivity: resolveAwardApprovalUserActivity(.init(
        cfg: cfg,
        awardApproval: awardApproval
      )),
      user: job.user.username,
      active: active
    ))
    return true
  }
  public func checkAwardApproval(cfg: Configuration, mode: AwardApproval.Mode) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let review = try gitlabCi.getParentMrState
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(_:from:))
      .get()
    let pipeline = try gitlabCi.parent.pipeline
      .flatMap(gitlabCi.getPipeline(pipeline:))
      .map(execute)
      .reduce(Json.GitlabPipeline.self, jsonDecoder.decode(_:from:))
      .get()
    guard pipeline.id == review.pipeline.id, review.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    let job = try gitlabCi.getCurrentJob
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(_:from:))
      .get()
    guard job.pipeline.ref == review.targetBranch else {
      logMessage(.init(message: "Target branch changed"))
      _ = try gitlabCi.postParentMrPipelines
        .map(execute)
        .get()
      return false
    }
    var approval = try resolveAwardApproval(.init(cfg: cfg))
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
    var merge: Flow.Merge? = nil
    switch mode {
    case .review:
      changedFiles = try Id(review.targetBranch)
        .map(Git.Branch.init(name:))
        .map(Git.Ref.make(remote:))
        .reduce(sha, cfg.git.listChangedFiles(source:target:))
        .map(execute)
        .map(String.make(utf8:))
        .get()
        .components(separatedBy: .newlines)
    case .replication:
      merge = try Lossy(.init(cfg: cfg))
        .map(resolveFlow)
        .flatMap(\.replication)
        .get()
        .makeMerge(supply: review.sourceBranch)
    case .integration:
      merge = try Lossy(.init(cfg: cfg))
        .map(resolveFlow)
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
          .map(resolveFlow)
          .flatMap(\.replication)
          .get()
          .makeMerge(supply: review.sourceBranch),
        review: review,
        pipeline: pipeline
      )
    }
    try approval.consider(
      sanityFiles: profile.sanityFiles,
      fileApproval: resolveCodeOwnage(.init(cfg: cfg, profile: profile)),
      changedFiles: changedFiles
    )
    let awards = try gitlabCi.getParentMrAwarders
      .map(execute)
      .reduce([Json.GitlabAward].self, jsonDecoder.decode(_:from:))
      .get()
    try approval.consider(awards: awards)
    for award in approval.state.unhighlighted {
      _ = try gitlabCi
        .postParentMrAward(award: award)
        .map(execute)
        .get()
    }
    if let reports = try approval.makeNewApprovals(cfg: cfg, review: review) {
      try reports
        .map(cfg.makeSendReport(report:))
        .forEach(sendReport)
      _ = try gitlabCi
        .putMrState(parameters: .init(
          addLabels: approval.state.unnotified
            .joined(separator: ","),
          removeLabels: Set(approval.allGroups.keys)
            .subtracting(approval.state.involved)
            .joined(separator: ",")
        ))
        .map(execute)
        .get()
    }
    if let unapprovedGroups = try approval.makeUnapprovedGroups() {
      unapprovedGroups.forEach { logMessage(.init(message: "\($0) unapproved")) }
      return false
    }
    if let holders = try approval.makeHoldersReport(cfg: cfg, review: review) {
      try sendReport(cfg.makeSendReport(report: holders))
      return false
    }
    return true
  }
  func resolveChanges(
    git: Git,
    gitlabCi: GitlabCi,
    merge: Flow.Merge,
    review: Json.GitlabReviewState,
    pipeline: Json.GitlabPipeline
  ) throws -> [String] {
    guard review.targetBranch == merge.target.name else { throw Thrown("Wrong target branch name") }
    guard pipeline.user.username != gitlabCi.botLogin else { return [] }
    let initial = try Id(.head)
      .map(git.getSha(ref:))
      .map(execute)
      .map(String.make(utf8:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let sha = try Git.Ref.make(sha: .init(value: pipeline.sha))
    _ = try Id
      .make(git.mergeBase(.make(remote: merge.target), sha))
      .map(execute)
      .map(String.make(utf8:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .map(git.detach(ref:))
      .map(execute)
    _ = try execute(git.clean)
    _ = try? execute(git.merge(
      ref: .make(sha: merge.fork),
      message: nil,
      noFf: true,
      env: [:]
    ))
    _ = try execute(git.quitMerge)
    _ = try execute(git.addAll)
    _ = try execute(git.resetSoft(ref: sha))
    _ = try execute(git.addAll)
    let result = try Id(git.listLocalChanges)
      .map(execute)
      .map(String.make(utf8:))
      .get()
      .components(separatedBy: .newlines)
    _ = try execute(git.resetHard(ref: initial))
    _ = try execute(git.clean)
    return result
  }
  func resolveParticipants(
    cfg: Configuration,
    gitlabCi: GitlabCi,
    merge: Flow.Merge
  ) throws -> [String] { try Id
    .make(cfg.git.listCommits(
      in: [.make(sha: merge.fork)],
      notIn: [.make(remote: merge.target)],
      noMerges: true,
      firstParents: false
    ))
    .map(execute)
    .map(String.make(utf8:))
    .get()
    .components(separatedBy: .newlines)
    .map(Git.Sha.init(value:))
    .flatMap { sha in try gitlabCi
      .listShaMergeRequests(sha: sha)
      .map(execute)
      .reduce([Json.GitlabCommitMergeRequest].self, jsonDecoder.decode(_:from:))
      .get()
      .filter { $0.squashCommitSha == sha.value }
      .map(\.author.username)
    }
  }
}
