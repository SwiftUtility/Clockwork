import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabAwardApprover {
  let handleFileList: Try.Reply<Git.HandleFileList>
  let handleLine: Try.Reply<Git.HandleLine>
  let handleVoid: Try.Reply<Git.HandleVoid>
  let getReviewState: Try.Reply<Gitlab.GetMrState>
  let postPipelines: Try.Reply<Gitlab.PostMrPipelines>
  let getPipeline: Try.Reply<Gitlab.GetPipeline>
  let getReviewAwarders: Try.Reply<Gitlab.GetMrAwarders>
  let postReviewAward: Try.Reply<Gitlab.PostMrAward>
  let listShaMergeRequests: Try.Reply<Gitlab.ListShaMergeRequests>
  let putState: Try.Reply<Gitlab.PutMrState>
  let resolveGitlab: Try.Reply<ResolveGitlab>
  let resolveProfile: Try.Reply<ResolveProfile>
  let resolveAwardApproval: Try.Reply<ResolveAwardApproval>
  let resolveFileApproval: Try.Reply<ResolveFileApproval>
  let sendReport: Try.Reply<SendReport>
  let logMessage: Act.Reply<LogMessage>
  public init(
    handleFileList: @escaping Try.Reply<Git.HandleFileList>,
    handleLine: @escaping Try.Reply<Git.HandleLine>,
    handleVoid: @escaping Try.Reply<Git.HandleVoid>,
    getReviewState: @escaping Try.Reply<Gitlab.GetMrState>,
    postPipelines: @escaping Try.Reply<Gitlab.PostMrPipelines>,
    getPipeline: @escaping Try.Reply<Gitlab.GetPipeline>,
    getReviewAwarders: @escaping Try.Reply<Gitlab.GetMrAwarders>,
    postReviewAward: @escaping Try.Reply<Gitlab.PostMrAward>,
    listShaMergeRequests: @escaping Try.Reply<Gitlab.ListShaMergeRequests>,
    putState: @escaping Try.Reply<Gitlab.PutMrState>,
    resolveGitlab: @escaping Try.Reply<ResolveGitlab>,
    resolveProfile: @escaping Try.Reply<ResolveProfile>,
    resolveAwardApproval: @escaping Try.Reply<ResolveAwardApproval>,
    resolveFileApproval: @escaping Try.Reply<ResolveFileApproval>,
    sendReport: @escaping Try.Reply<SendReport>,
    logMessage: @escaping Act.Reply<LogMessage>
  ) {
    self.handleFileList = handleFileList
    self.handleLine = handleLine
    self.handleVoid = handleVoid
    self.getReviewState = getReviewState
    self.postPipelines = postPipelines
    self.getPipeline = getPipeline
    self.getReviewAwarders = getReviewAwarders
    self.postReviewAward = postReviewAward
    self.listShaMergeRequests = listShaMergeRequests
    self.putState = putState
    self.resolveGitlab = resolveGitlab
    self.resolveProfile = resolveProfile
    self.resolveAwardApproval = resolveAwardApproval
    self.resolveFileApproval = resolveFileApproval
    self.sendReport = sendReport
    self.logMessage = logMessage
  }
  public func checkAwardApproval(cfg: Configuration, mode: Mode) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let state = try getReviewState(gitlab.getParentMrState())
    let pipeline = try gitlab.triggererPipeline
      .or { throw Thrown("No env \(gitlab.parentPipeline)") }
    guard pipeline == state.pipeline.id, state.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    guard try cfg.get(env: Gitlab.commitBranch) == state.targetBranch else {
      logMessage(.init(message: "Target branch changed"))
      _ = try postPipelines(gitlab.postParentMrPipelines())
      return false
    }
    var approval = try resolveAwardApproval(.init(cfg: cfg))
    approval.consider(state: state)
    let sha = try Id(state.pipeline.sha)
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let profile = try resolveProfile(.init(git: cfg.git, file: .init(
      ref: sha,
      path: gitlab.triggererProfile
        .or { throw Thrown("No env \(gitlab.parentProfile)") }
    )))
    let changedFiles: [String]
    var resolver: String?
    switch mode {
    case .review:
      changedFiles = try handleFileList(cfg.git.listChangedFiles(
        source: sha,
        target: .make(remote: .init(name: state.targetBranch))
      ))
      resolver = state.author.username
    case .replication:
      changedFiles = try resolveChanges(
        git: cfg.git,
        gitlab: gitlab,
        merge: cfg.getReplication().makeMerge(branch: state.sourceBranch),
        state: state,
        sha: sha
      )
    case .integration:
      changedFiles = try resolveChanges(
        git: cfg.git,
        gitlab: gitlab,
        merge: cfg.getIntegration().makeMerge(branch: state.sourceBranch),
        state: state,
        sha: sha
      )
    }
    try approval.consider(resolver: try resolver.flatMapNil {
      try resolveOriginalAuthor(cfg: cfg, gitlab: gitlab, sha: .init(value: state.pipeline.sha))
    })
    try approval.consider(
      sanityFiles: gitlab.sanityFiles + profile.sanityFiles,
      fileApproval: resolveFileApproval(.init(cfg: cfg, profile: profile))
        .or { throw Thrown("No fileOwnage in profile") },
      changedFiles: changedFiles
    )
    try approval.consider(awards: getReviewAwarders(gitlab.getParentMrAwarders()))
    for award in approval.unhighlighted {
      _ = try postReviewAward(gitlab.postParentMrAward(award: award))
    }
    if let reports = try approval.makeNewApprovals(cfg: cfg, state: state) {
      try reports.forEach { try sendReport(.init(cfg: cfg, report: $0)) }
      _ = try putState(gitlab.putMrState(parameters: .init(
        addLabels: approval.unnotified
          .joined(separator: ","),
        removeLabels: Set(approval.groups.keys)
          .subtracting(approval.involved)
          .joined(separator: ",")
      )))
    }
    if let unapprovedGroups = try approval.makeUnapprovedGroups() {
      unapprovedGroups.forEach { logMessage(.init(message: "\($0) unapproved")) }
      return false
    }
    if let holders = try approval.makeHoldersReport(cfg: cfg, state: state) {
      try sendReport(.init(cfg: cfg, report: holders))
      return false
    }
    return true
  }
  func resolveChanges(
    git: Git,
    gitlab: Gitlab,
    merge: Configuration.Merge,
    state: Json.GitlabReviewState,
    sha: Git.Ref
  ) throws -> [String] {
    guard state.targetBranch == merge.target.name else { throw Thrown("Wrong target branch name") }
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    guard pipeline.user.username != gitlab.botLogin else { return [] }
    let initial = try Git.Ref.make(sha: .init(value: handleLine(git.getSha(ref: .head))))
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
  func resolveOriginalAuthor(
    cfg: Configuration,
    gitlab: Gitlab,
    sha: Git.Sha
  ) throws -> String? {
    let parents = try handleLine(cfg.git.listParrents(ref: .make(sha: sha)))
      .components(separatedBy: .newlines)
    switch parents.count {
    case 1:
      return try listShaMergeRequests(gitlab.listShaMergeRequests(sha: sha))
        .first { $0.squashCommitSha == sha.value }
        .map(\.author.username)
    case 2:
      return try resolveOriginalAuthor(cfg: cfg, gitlab: gitlab, sha: .init(value: parents.end))
    default:
      throw Thrown("\(sha.value) has \(parents.count) parents")
    }
  }
  public enum Mode {
    case review
    case replication
    case integration
  }
}
