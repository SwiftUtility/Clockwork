import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabAwardApprover {
  let handleFileList: Try.Reply<Git.HandleFileList>
  let handleLine: Try.Reply<Git.HandleLine>
  let handleVoid: Try.Reply<Git.HandleVoid>
  let handleApi: Try.Reply<GitlabCi.HandleApi>
  let resolveProfile: Try.Reply<ResolveProfile>
  let resolveAwardApproval: Try.Reply<ResolveAwardApproval>
  let resolveAwardApprovalUserActivity: Try.Reply<ResolveAwardApprovalUserActivity>
  let resolveCodeOwnage: Try.Reply<ResolveCodeOwnage>
  let persistUserActivity: Try.Reply<PersistUserActivity>
  let resolveFlow: Try.Reply<ResolveFlow>
  let sendReport: Try.Reply<SendReport>
  let logMessage: Act.Reply<LogMessage>
  let dialect: AnyCodable.Dialect
  public init(
    handleFileList: @escaping Try.Reply<Git.HandleFileList>,
    handleLine: @escaping Try.Reply<Git.HandleLine>,
    handleVoid: @escaping Try.Reply<Git.HandleVoid>,
    handleApi: @escaping Try.Reply<GitlabCi.HandleApi>,
    resolveProfile: @escaping Try.Reply<ResolveProfile>,
    resolveAwardApproval: @escaping Try.Reply<ResolveAwardApproval>,
    resolveAwardApprovalUserActivity: @escaping Try.Reply<ResolveAwardApprovalUserActivity>,
    resolveCodeOwnage: @escaping Try.Reply<ResolveCodeOwnage>,
    persistUserActivity: @escaping Try.Reply<PersistUserActivity>,
    resolveFlow: @escaping Try.Reply<ResolveFlow>,
    sendReport: @escaping Try.Reply<SendReport>,
    logMessage: @escaping Act.Reply<LogMessage>,
    dialect: AnyCodable.Dialect
  ) {
    self.handleFileList = handleFileList
    self.handleLine = handleLine
    self.handleVoid = handleVoid
    self.handleApi = handleApi
    self.resolveProfile = resolveProfile
    self.resolveAwardApproval = resolveAwardApproval
    self.resolveAwardApprovalUserActivity = resolveAwardApprovalUserActivity
    self.resolveCodeOwnage = resolveCodeOwnage
    self.persistUserActivity = persistUserActivity
    self.resolveFlow = resolveFlow
    self.sendReport = sendReport
    self.logMessage = logMessage
    self.dialect = dialect
  }
  public func updateUser(cfg: Configuration, active: Bool) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let job = try gitlabCi.getCurrentJob
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
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
      .map(handleApi)
      .reduce(Json.GitlabReviewState.self, dialect.read(_:from:))
      .get()
    let pipeline = try gitlabCi.parent.pipeline
      .flatMap(gitlabCi.getPipeline(pipeline:))
      .map(handleApi)
      .reduce(Json.GitlabPipeline.self, dialect.read(_:from:))
      .get()
    guard pipeline.id == review.pipeline.id, review.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    let job = try gitlabCi.getCurrentJob
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
      .get()
    guard job.pipeline.ref == review.targetBranch else {
      logMessage(.init(message: "Target branch changed"))
      _ = try gitlabCi.postParentMrPipelines
        .map(handleApi)
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
      changedFiles = try handleFileList(cfg.git.listChangedFiles(
        source: sha,
        target: .make(remote: .init(name: review.targetBranch))
      ))
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
      .map(handleApi)
      .reduce([Json.GitlabAward].self, dialect.read(_:from:))
      .get()
    try approval.consider(awards: awards)
    for award in approval.state.unhighlighted {
      _ = try gitlabCi
        .postParentMrAward(award: award)
        .map(handleApi)
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
        .map(handleApi)
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
    let initial = try Git.Ref.make(sha: .init(value: handleLine(git.getSha(ref: .head))))
    let sha = try Git.Ref.make(sha: .init(value: pipeline.sha))
    let base = try handleLine(git.mergeBase(.make(remote: merge.target), sha))
    try handleVoid(git.detach(to: .make(sha: .init(value: base))))
    try handleVoid(git.clean)
    try? handleVoid(git.make(merge: .init(
      ref: .make(sha: merge.fork),
      message: nil,
      noFf: true,
      env: [:]
    )))
    try handleVoid(git.quitMerge)
    try handleVoid(git.addAll)
    try handleVoid(git.resetSoft(ref: sha))
    try handleVoid(git.addAll)
    let result = try handleFileList(git.listLocalChanges)
    try handleVoid(git.resetHard(ref: initial))
    try handleVoid(git.clean)
    return result
  }
  func resolveParticipants(
    cfg: Configuration,
    gitlabCi: GitlabCi,
    merge: Flow.Merge
  ) throws -> [String] { try Id
    .make(.init(
      include: [.make(sha: merge.fork)],
      exclude: [.make(remote: merge.target)],
      noMerges: true,
      firstParents: false
    ))
    .map(cfg.git.make(listCommits:))
    .map(handleLine)
    .get()
    .components(separatedBy: .newlines)
    .map(Git.Sha.init(value:))
    .flatMap { sha in try gitlabCi
      .listShaMergeRequests(sha: sha)
      .map(handleApi)
      .reduce([Json.GitlabCommitMergeRequest].self, dialect.read(_:from:))
      .get()
      .filter { $0.squashCommitSha == sha.value }
      .map(\.author.username)
    }
  }
}
