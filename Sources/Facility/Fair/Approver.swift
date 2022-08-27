import Foundation
import Facility
import FacilityPure
public final class Approver {
  let execute: Try.Reply<Execute>
  let resolveProfile: Try.Reply<Configuration.ResolveProfile>
  let resolveAwardApproval: Try.Reply<Configuration.ResolveAwardApproval>
  let resolveUserActivity: Try.Reply<Configuration.ResolveUserActivity>
  let resolveCodeOwnage: Try.Reply<Configuration.ResolveCodeOwnage>
  let persistUserActivity: Try.Reply<Configuration.PersistUserActivity>
  let resolveFusion: Try.Reply<Configuration.ResolveFusion>
  let report: Act.Reply<Report>
  let logMessage: Act.Reply<LogMessage>
  let worker: Worker
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveProfile: @escaping Try.Reply<Configuration.ResolveProfile>,
    resolveAwardApproval: @escaping Try.Reply<Configuration.ResolveAwardApproval>,
    resolveUserActivity: @escaping Try.Reply<Configuration.ResolveUserActivity>,
    resolveCodeOwnage: @escaping Try.Reply<Configuration.ResolveCodeOwnage>,
    persistUserActivity: @escaping Try.Reply<Configuration.PersistUserActivity>,
    resolveFusion: @escaping Try.Reply<Configuration.ResolveFusion>,
    report: @escaping Act.Reply<Report>,
    logMessage: @escaping Act.Reply<LogMessage>,
    worker: Worker,
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
    self.worker = worker
    self.jsonDecoder = jsonDecoder
  }
  public func updateUser(cfg: Configuration, active: Bool, login: String) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let awardApproval = try resolveAwardApproval(.init(cfg: cfg))
    let userActivity = try resolveUserActivity(.init(cfg: cfg, awardApproval: awardApproval))
    if case active = userActivity[gitlabCi.job.user.username] { return true }
    try persistUserActivity(.init(
      cfg: cfg,
      pushUrl: gitlabCi.pushUrl.get(),
      awardApproval: awardApproval,
      userActivity: userActivity,
      user: login.isEmpty.then(gitlabCi.job.user.username).get(login),
      active: active
    ))
    return true
  }
  public func checkAwardApproval(
    cfg: Configuration,
    mode: AwardApproval.Mode,
    remind: Bool
  ) throws -> Bool {
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    let pipeline = try ctx.gitlab.getPipeline(pipeline: ctx.review.pipeline.id)
      .map(execute)
      .reduce(Json.GitlabPipeline.self, jsonDecoder.decode(success:reply:))
      .get()
    let approval = try resolveAwardApproval(.init(cfg: cfg))
    let sha = try Id(ctx.review.pipeline.sha)
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let merge: Fusion.Merge?
    switch mode {
    case .resolution:
      merge = nil
    case .replication:
      merge = try Lossy(.init(cfg: cfg))
        .map(resolveFusion)
        .flatMap(\.replication)
        .get()
        .makeMerge(supply: ctx.review.sourceBranch)
    case .integration:
      merge = try Lossy(.init(cfg: cfg))
        .map(resolveFusion)
        .flatMap(\.integration)
        .get()
        .makeMerge(supply: ctx.review.sourceBranch)
    }
    let participants: [String]
    let changedFiles: [String]
    if let merge = merge {
      participants = try worker.resolveParticipants(
        cfg: cfg,
        gitlabCi: ctx.gitlab,
        merge: merge
      )
      changedFiles = try resolveChanges(
        git: cfg.git,
        gitlabCi: ctx.gitlab,
        merge: merge,
        review: ctx.review,
        pipeline: pipeline
      )
    } else {
      participants = []
      changedFiles = try Id(ctx.review.targetBranch)
        .map(Git.Branch.init(name:))
        .map(Git.Ref.make(remote:))
        .reduce(sha, cfg.git.listChangedFiles(source:target:))
        .map(execute)
        .map(Execute.parseLines(reply:))
        .get()
    }
    let users = try AwardApproval.Users(
      bot: ctx.gitlab.botLogin,
      author: ctx.review.author.username,
      participants: participants,
      approval: approval,
      awards: ctx.gitlab.getMrAwarders(review: ctx.review.iid)
        .map(execute)
        .reduce([Json.GitlabAward].self, jsonDecoder.decode(success:reply:))
        .get(),
      userActivity: resolveUserActivity(.init(cfg: cfg, awardApproval: approval))
    )
    let profile = try resolveProfile(.init(git: cfg.git, file: .init(
      ref: sha,
      path: ctx.profile
    )))
    let groups = try AwardApproval.Groups(
      sourceBranch: ctx.review.sourceBranch,
      targetBranch: ctx.review.targetBranch,
      labels: ctx.review.labels,
      users: users,
      approval: approval,
      sanityFiles: profile.sanityFiles + [ctx.gitlab.config],
      fileApproval: resolveCodeOwnage(.init(cfg: cfg, profile: profile)),
      changedFiles: changedFiles
    )
    for award in groups.unhighlighted {
      try ctx.gitlab
        .postMrAward(review: ctx.review.iid, award: award)
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
    }
    if !groups.unreported.isEmpty {
      report(cfg.reportNewAwardApprovals(
        review: ctx.review,
        users: users.coauthors,
        groups: groups.unreported
      ))
      groups.unreported.forEach { group in report(cfg.reportNewAwardApproval(
        review: ctx.review,
        users: users.coauthors,
        group: group
      ))}
    }
    if groups.emergency, !groups.cheaters.isEmpty {
      report(cfg.reportEmergencyAwardApproval(
        review: ctx.review,
        users: users.coauthors,
        cheaters: groups.cheaters
      ))
    }
    if !groups.neededLabels.isEmpty || !groups.extraLabels.isEmpty {
      try ctx.gitlab
        .putMrState(
          parameters: .init(
            addLabels: groups.neededLabels.isEmpty.else(groups.neededLabels),
            removeLabels: groups.extraLabels.isEmpty.else(groups.extraLabels)
          ),
          review: ctx.review.iid
        )
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
    }
    if remind, !groups.emergency, groups.unreported.isEmpty, !groups.unapproved.isEmpty {
      report(cfg.reportWaitAwardApprovals(
        review: ctx.review,
        users: users.coauthors,
        groups: groups.unapproved
      ))
      groups.unapproved.forEach { group in report(cfg.reportWaitAwardApproval(
        review: ctx.review,
        users: users.coauthors,
        group: group
      ))}
    }
    guard groups.emergency || groups.unapproved.isEmpty else {
      groups.unapproved.forEach { logMessage(.init(message: "\($0.name) unapproved")) }
      return false
    }
    guard groups.holders.isEmpty else {
      logMessage(.init(message: "On hold by: \(groups.holders.joined(separator: ", "))"))
      report(cfg.reportAwardApprovalHolders(
        review: ctx.review,
        users: users.coauthors,
        holders: groups.holders
      ))
      return false
    }
    if groups.reportSuccess {
      report(cfg.reportAwardApprovalReady(review: ctx.review, users: users.coauthors))
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
}
