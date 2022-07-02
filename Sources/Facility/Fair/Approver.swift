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
  public func checkAwardApproval(
    cfg: Configuration,
    mode: AwardApproval.Mode,
    remind: Bool
  ) throws -> Bool {
    guard let ctx = try worker.resolveParentReview(cfg: cfg) else { return false }
    let pipeline = try ctx.gitlab.getPipeline(pipeline: ctx.review.pipeline.id)
      .map(execute)
      .reduce(Json.GitlabPipeline.self, jsonDecoder.decode(success:reply:))
      .get()
    guard ctx.gitlab.job.pipeline.ref == ctx.review.targetBranch else {
      logMessage(.init(message: "Target branch changed"))
      try ctx.gitlab.postMrPipelines(review: ctx.review.iid)
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
      return false
    }
    let approval = try resolveAwardApproval(.init(cfg: cfg))
    let sha = try Id(ctx.review.pipeline.sha)
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    1.debug()
    let merge: Fusion.Merge?
    1.debug()
    switch mode {
    case .resolution:
      merge = nil
      1.debug()
    case .replication:
      1.debug()
      merge = try Lossy(.init(cfg: cfg))
        .map(resolveFusion)
        .flatMap(\.replication)
        .get()
        .makeMerge(supply: ctx.review.sourceBranch)
      1.debug()
    case .integration:
      1.debug()
      merge = try Lossy(.init(cfg: cfg))
        .map(resolveFusion)
        .flatMap(\.integration)
        .get()
        .makeMerge(supply: ctx.review.sourceBranch)
      1.debug()
    }
    let participants: [String]
    let changedFiles: [String]
    if let merge = merge {
      1.debug()
      participants = try worker.resolveParticipants(
        cfg: cfg,
        gitlabCi: ctx.gitlab,
        merge: merge
      )
      1.debug()
      changedFiles = try resolveChanges(
        git: cfg.git,
        gitlabCi: ctx.gitlab,
        merge: try Lossy(.init(cfg: cfg))
          .map(resolveFusion)
          .flatMap(\.replication)
          .get()
          .makeMerge(supply: ctx.review.sourceBranch),
        review: ctx.review,
        pipeline: pipeline
      )
      1.debug()
    } else {
      1.debug()
      participants = []
      changedFiles = try Id(ctx.review.targetBranch)
        .map(Git.Branch.init(name:)).debug()
        .map(Git.Ref.make(remote:))
        .reduce(sha, cfg.git.listChangedFiles(source:target:))
        .map(execute)
        .map(Execute.parseLines(reply:)).debug()
        .get()
      1.debug()
    }
    1.debug()
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
    1.debug()
    let profile = try resolveProfile(.init(git: cfg.git, file: .init(
      ref: sha,
      path: ctx.profile
    )))
    1.debug()
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
    1.debug()
    for award in groups.unhighlighted {
      try ctx.gitlab
        .postMrAward(review: ctx.review.iid, award: award)
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
    }
    if !groups.unreported.isEmpty {
      1.debug()
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
      1.debug()
      report(cfg.reportEmergencyAwardApproval(
        review: ctx.review,
        users: users.coauthors,
        cheaters: groups.cheaters
      ))
    }
    if !groups.neededLabels.isEmpty || !groups.extraLabels.isEmpty {
      1.debug()
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
      1.debug()
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
      1.debug()
      groups.unapproved.forEach { logMessage(.init(message: "\($0.name) unapproved")) }
      return false
    }
    guard groups.holders.isEmpty else {
      1.debug()
      logMessage(.init(message: "On hold by: \(groups.holders.joined(separator: ", "))"))
      report(cfg.reportAwardApprovalHolders(
        review: ctx.review,
        users: users.coauthors,
        holders: groups.holders
      ))
      return false
    }
    if groups.reportSuccess {
      1.debug()
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
      .map(Execute.parseText(reply:)).debug()
      .map(Git.Sha.init(value:)).debug()
      .map(Git.Ref.make(sha:))
      .get()
    let sha = try Git.Ref.make(sha: .init(value: pipeline.sha.debug()))
    try Id
      .make(git.mergeBase(.make(remote: merge.target), sha))
      .map(execute)
      .map(Execute.parseText(reply:)).debug()
      .map(Git.Sha.init(value:)).debug()
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
