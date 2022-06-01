import Foundation
import Combine
import Facility
import FacilityAutomates
import FacilityQueries
public struct Laborer {
  public var handleFileList: Try.Reply<Git.HandleFileList>
  public var handleLine: Try.Reply<Git.HandleLine>
  public var handleVoid: Try.Reply<Git.HandleVoid>
  public var getReviewState: Try.Reply<Gitlab.GetMrState>
  public var getReviewAwarders: Try.Reply<Gitlab.GetMrAwarders>
  public var postPipelines: Try.Reply<Gitlab.PostMrPipelines>
  public var postReviewAward: Try.Reply<Gitlab.PostMrAward>
  public var putMerge: Try.Reply<Gitlab.PutMrMerge>
  public var putRebase: Try.Reply<Gitlab.PutMrRebase>
  public var putState: Try.Reply<Gitlab.PutMrState>
  public var getPipeline: Try.Reply<Gitlab.GetPipeline>
  public var postTriggerPipeline: Try.Reply<Gitlab.PostTriggerPipeline>
  public var postMergeRequests: Try.Reply<Gitlab.PostMergeRequests>
  public var listShaMergeRequests: Try.Reply<Gitlab.ListShaMergeRequests>
  public var renderStencil: Try.Reply<RenderStencil>
  public var resolveGitlab: Try.Reply<ResolveGitlab>
  public var resolveProfile: Try.Reply<ResolveProfile>
  public var resolveFileApproval: Try.Reply<ResolveFileApproval>
  public var resolveAwardApproval: Try.Reply<ResolveAwardApproval>
  public var resolveVacationers: Try.Reply<ResolveVacationers>
  public var sendReport: Try.Reply<SendReport>
  public var logMessage: Act.Reply<LogMessage>
  public var printLine: Act.Of<String>.Go
  public init(
    handleFileList: @escaping Try.Reply<Git.HandleFileList>,
    handleLine: @escaping Try.Reply<Git.HandleLine>,
    handleVoid: @escaping Try.Reply<Git.HandleVoid>,
    getReviewState: @escaping Try.Reply<Gitlab.GetMrState>,
    getReviewAwarders: @escaping Try.Reply<Gitlab.GetMrAwarders>,
    postPipelines: @escaping Try.Reply<Gitlab.PostMrPipelines>,
    postReviewAward: @escaping Try.Reply<Gitlab.PostMrAward>,
    putMerge: @escaping Try.Reply<Gitlab.PutMrMerge>,
    putRebase: @escaping Try.Reply<Gitlab.PutMrRebase>,
    putState: @escaping Try.Reply<Gitlab.PutMrState>,
    getPipeline: @escaping Try.Reply<Gitlab.GetPipeline>,
    postTriggerPipeline: @escaping Try.Reply<Gitlab.PostTriggerPipeline>,
    postMergeRequests: @escaping Try.Reply<Gitlab.PostMergeRequests>,
    listShaMergeRequests: @escaping Try.Reply<Gitlab.ListShaMergeRequests>,
    renderStencil: @escaping Try.Reply<RenderStencil>,
    resolveGitlab: @escaping Try.Reply<ResolveGitlab>,
    resolveProfile: @escaping Try.Reply<ResolveProfile>,
    resolveFileApproval: @escaping Try.Reply<ResolveFileApproval>,
    resolveAwardApproval: @escaping Try.Reply<ResolveAwardApproval>,
    resolveVacationers: @escaping Try.Reply<ResolveVacationers>,
    sendReport: @escaping Try.Reply<SendReport>,
    logMessage: @escaping Act.Reply<LogMessage>,
    printLine: @escaping Act.Of<String>.Go
  ) {
    self.handleFileList = handleFileList
    self.handleLine = handleLine
    self.handleVoid = handleVoid
    self.getReviewState = getReviewState
    self.getReviewAwarders = getReviewAwarders
    self.postPipelines = postPipelines
    self.postReviewAward = postReviewAward
    self.putMerge = putMerge
    self.putRebase = putRebase
    self.putState = putState
    self.getPipeline = getPipeline
    self.postTriggerPipeline = postTriggerPipeline
    self.postMergeRequests = postMergeRequests
    self.listShaMergeRequests = listShaMergeRequests
    self.renderStencil = renderStencil
    self.resolveGitlab = resolveGitlab
    self.resolveProfile = resolveProfile
    self.resolveFileApproval = resolveFileApproval
    self.resolveAwardApproval = resolveAwardApproval
    self.resolveVacationers = resolveVacationers
    self.sendReport = sendReport
    self.logMessage = logMessage
    self.printLine = printLine
  }
  public func checkAwardApproval(
    query: Gitlab.CheckAwardApproval
  ) throws -> Gitlab.CheckAwardApproval.Reply {
    let gitlab = try resolveGitlab(.init(cfg: query.cfg))
    let state = try getReviewState(gitlab.getParentMrState())
    let pipeline = try gitlab.triggererPipeline
      .or { throw Thrown("No env \(gitlab.parentPipeline)") }
    guard pipeline == state.pipeline.id, state.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    guard try query.cfg.get(env: Gitlab.commitBranch) == state.targetBranch else {
      logMessage(.init(message: "Target branch changed"))
      _ = try postPipelines(gitlab.postParentMrPipelines())
      return false
    }
    var approval = try resolveAwardApproval(.init(cfg: query.cfg))
      .or { throw Thrown("No approval in profile") }
    approval.consider(state: state)
    let sha = try Id(state.pipeline.sha)
      .map(Git.Sha.init(ref:))
      .map(Git.Ref.make(sha:))
      .get()
    let profile = try resolveProfile(.init(git: query.cfg.git, file: .init(
      ref: sha,
      path: gitlab.triggererProfile
        .or { throw Thrown("No env \(gitlab.parentProfile)") }
    )))
    let changedFiles: [String]
    var resolver: String?
    switch query.mode {
    case .review:
      changedFiles = try handleFileList(query.cfg.git.listChangedFiles(
        source: sha,
        target: .make(remote: .init(name: state.targetBranch))
      ))
      resolver = state.author.username
    case .replication:
      changedFiles = try resolveChanges(
        git: query.cfg.git,
        gitlab: gitlab,
        merge: query.cfg.getReplication().makeMerge(branch: state.sourceBranch),
        state: state,
        sha: sha
      )
    case .integration:
      changedFiles = try resolveChanges(
        git: query.cfg.git,
        gitlab: gitlab,
        merge: query.cfg.getIntegration().makeMerge(branch: state.sourceBranch),
        state: state,
        sha: sha
      )
    }
    try approval.consider(resolver: try resolver.flatMapNil {
      try resolveOriginalAuthor(cfg: query.cfg, gitlab: gitlab, sha: .init(ref: state.pipeline.sha))
    })
    try approval.consider(
      sanityFiles: gitlab.sanityFiles + profile.sanityFiles,
      fileApproval: resolveFileApproval(.init(cfg: query.cfg, profile: profile))
        .or { throw Thrown("No fileOwnage in profile") },
      changedFiles: changedFiles
    )
    try approval.consider(
      awards: getReviewAwarders(gitlab.getParentMrAwarders()),
      vacationers: resolveVacationers(.init(cfg: query.cfg))
    )
    for award in approval.unhighlighted {
      _ = try postReviewAward(gitlab.postParentMrAward(award: award))
    }
    if let reports = try approval.makeNewApprovals(cfg: query.cfg, state: state) {
      try reports.forEach { try sendReport(.init(cfg: query.cfg, report: $0)) }
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
    if let holders = try approval.makeHoldersReport(cfg: query.cfg, state: state) {
      try sendReport(.init(cfg: query.cfg, report: holders))
      return false
    }
    return true
  }
  public func triggerTargetPipeline(
    query: Gitlab.TriggerPipeline
  ) throws -> Gitlab.TriggerPipeline.Reply {
    let gitlab = try resolveGitlab(.init(cfg: query.cfg))
    var variables = try gitlab.makeTriggererVariables(cfg: query.cfg)
    for variable in query.context {
      let index = try variable.firstIndex(of: "=")
        .or { throw Thrown("wrong argument format \(variable)") }
      let key = variable[variable.startIndex..<index]
      let value = variable[index..<variable.endIndex].dropFirst()
      variables[.init(key)] = .init(value)
    }
    _ = try postTriggerPipeline(gitlab.postTriggerPipeline(
      ref: query.ref,
      variables: variables
    ))
    return true
  }
  public func addReviewLabels(
    query: Gitlab.AddReviewLabels
  ) throws -> Gitlab.AddReviewLabels.Reply {
    let gitlab = try resolveGitlab(.init(cfg: query.cfg))
    let state = try getReviewState(gitlab.getParentMrState())
    guard
      case state.pipeline.id? = gitlab.triggererPipeline,
      state.state == "opened"
    else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    let labels = Set(query.labels).subtracting(.init(state.labels))
    guard !labels.isEmpty else {
      logMessage(.init(message: "No new labels"))
      return true
    }
    _ = try putState(gitlab.putMrState(parameters: .init(
      addLabels: labels.joined(separator: ",")
    )))
    logMessage(.init(message: "Labels added"))
    _ = try postPipelines(gitlab.postParentMrPipelines())
    return true
  }
  public func acceptReview(
    query: Gitlab.AcceptReview
  ) throws -> Gitlab.AcceptReview.Reply {
    let gitlab = try resolveGitlab(.init(cfg: query.cfg))
    let state = try getReviewState(gitlab.getParentMrState())
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    guard pipeline.id == state.pipeline.id, state.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return true
    }
    guard try query.cfg.get(env: Gitlab.commitBranch) == state.targetBranch else {
      logMessage(.init(message: "Target branch changed"))
      _ = try postPipelines(gitlab.postParentMrPipelines())
      return true
    }
    guard try checkAcceptIssues(cfg: query.cfg, state: state, pipeline: pipeline) else { return true }
    let head = try Git.Sha(ref: state.pipeline.sha)
    let target = try Git.Ref.make(remote: .init(name: state.targetBranch))
    let message = try query.cfg.review
      .flatMap(\.messageTemplate)
      .reduce(Report.Context.make(review: state), query.cfg.makeRenderStencil(context:template:))
      .flatMap(renderStencil)
      .or { throw Thrown("Commit message is empty") }
    guard case ()? = try? handleVoid(query.cfg.git.check(
      child: .make(sha: head),
      parent: target
    )) else {
      if let sha = try commitMerge(
        cfg: query.cfg,
        into: target,
        message: message,
        sha: head
      ) {
        logMessage(.init(message: "Review was rebased"))
        try handleVoid(query.cfg.git.make(push: .init(
          url: gitlab.makePushUrl(),
          branch: .init(name: state.sourceBranch),
          sha: sha,
          force: true
        )))
      } else {
        logMessage(.init(message: "Automatic rebase failed"))
        try sendReport(.init(cfg: query.cfg, report: .review(state, .mergeConflicts)))
      }
      return true
    }
    let result = try putMerge(gitlab.putMrMerge(parameters: .init(
      mergeCommitMessage: message,
      squash: true,
      shouldRemoveSourceBranch: true,
      sha: head
    )))
    if case "merged"? = result.map?["state"]?.value?.string {
      logMessage(.init(message: "Review merged"))
      try sendReport(.init(cfg: query.cfg, report: .review(state, .accepted)))
      return true
    } else if let message = result.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      try sendReport(.init(cfg: query.cfg, report: .review(state, .mergeError(message))))
      return true
    } else {
      throw MayDay("Accept review responce not handled")
    }
  }
  public func startIntegration(configuration cfg: Configuration, target: String) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let integration = try cfg.getIntegration()
    let pushUrl = try gitlab.makePushUrl()
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    let merge = try integration.makeMerge(target: target, source: pipeline.ref, sha: pipeline.sha)
    guard integration.rules.contains(where: { rule in
      rule.users.contains(gitlab.user)
      && rule.target.isMet(merge.target.name)
      && rule.source.isMet(merge.source.name)
    }) else { throw Thrown("Integration not allowed for \(gitlab.user)") }
    guard case nil = try? handleVoid(cfg.git.check(
      child: .make(remote: merge.target),
      parent: .make(sha: merge.fork)
    )) else {
      logMessage(.init(message: "\(merge.target.name) already contains \(merge.fork.ref)"))
      return true
    }
    guard case nil = try? handleLine(cfg.git.checkRefType(
      ref: .make(remote: merge.supply)
    )) else {
      logMessage(.init(message: "Integration already in progress"))
      return true
    }
    let message = try renderStencil(cfg.makeRenderStencil(merge: merge))
      .or { throw Thrown("Empty commit message") }
    let sha: Git.Sha
    if case nil = try? handleVoid(cfg.git.check(
      child: .make(sha: merge.fork),
      parent: .make(remote: merge.target)
    )) {
      sha = merge.fork
    } else {
      sha = try commitMerge(
        cfg: cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: merge.fork
      ) ?? merge.fork
    }
    try handleVoid(cfg.git.make(push: .init(
      url: pushUrl,
      branch: merge.supply,
      sha: sha,
      force: false
    )))
    _ = try postMergeRequests(gitlab.postMergeRequests(parameters: .init(
      sourceBranch: merge.supply.name,
      targetBranch: merge.target.name,
      title: message
    )))
    return true
  }
  public func finishIntegration(configuration cfg: Configuration) throws -> Bool {
    fatalError()
  }
  public func generateIntegrationJobs(
    query: Gitlab.GenerateIntegrationJobs
  ) throws -> Gitlab.GenerateIntegrationJobs.Reply {
    let gitlab = try resolveGitlab(.init(cfg: query.cfg))
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    let fork = try Git.Sha(ref: pipeline.sha)
    let source = try Git.Branch(name: pipeline.ref)
    let rules = try query.cfg.getIntegration().rules
      .filter { $0.source.isMet(source.name) }
      .mapEmpty { throw Thrown("Integration for \(source.name) not configured") }
    var targets: [Git.Branch] = []
    for line in try handleLine(query.cfg.git.listLocalRefs).components(separatedBy: .newlines) {
      let pair = line.components(separatedBy: .whitespaces)
      guard pair.count == 2 else { throw MayDay("bad git reply") }
      guard let target = try? pair[1].dropPrefix("refs/remotes/origin/") else { continue }
      guard rules.contains(where: { $0.target.isMet(target) }) else { continue }
      let sha = try Git.Sha.init(ref: pair[0])
      guard case nil = try? handleVoid(query.cfg.git.check(
        child: .make(sha: sha),
        parent: .make(sha: fork)
      )) else { continue }
      try targets.append(.init(name: target))
    }
    guard !targets.isEmpty else { throw Thrown("No branches suitable for integration") }
    var result = ["include: $\(Gitlab.configPath)"]
    for target in targets {
      result += try renderStencil(query.cfg.makeRenderIntegrationJob(target: target.name))
        .or { throw Thrown("Rendered job is empty") }
        .components(separatedBy: .newlines)
    }
    result.forEach(printLine)
    return true
  }
  public func performReplication(
    query: Gitlab.PerformReplication
  ) throws -> Gitlab.PerformReplication.Reply {
    let gitlab = try resolveGitlab(.init(cfg: query.cfg))
    let replication = try query.cfg.getReplication()
    let pushUrl = try gitlab.makePushUrl()
    guard gitlab.triggererPipeline != nil else {
      let branch = try query.cfg.get(env: Gitlab.commitBranch)
      guard replication.source.isMet(branch) else {
        throw Thrown("Replication blocked by configuration")
      }
      guard let merge = try makeMerge(
        cfg: query.cfg,
        replication: replication,
        branch: query.cfg.get(env: Gitlab.commitBranch)
      ) else {
        logMessage(.init(message: "No commits to replicate"))
        return true
      }
      guard case nil = try? handleLine(query.cfg.git.checkRefType(
        ref: .make(remote: merge.supply)
      )) else {
        logMessage(.init(message: "Replication already in progress"))
        return true
      }
      let message = try renderStencil(query.cfg.makeRenderStencil(merge: merge))
        .or { throw Thrown("Empty commit message") }
      let sha = try commitMerge(
        cfg: query.cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: merge.fork
      ) ?? merge.fork
      try handleVoid(query.cfg.git.make(push: .init(
        url: pushUrl,
        branch: merge.supply,
        sha: sha,
        force: false
      )))
      _ = try postMergeRequests(gitlab.postMergeRequests(parameters: .init(
        sourceBranch: merge.supply.name, targetBranch: merge.target.name, title: message
      )))
      return true
    }
    let state = try getReviewState(gitlab.getParentMrState())
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    guard
      case state.targetBranch = try query.cfg.get(env: Gitlab.commitBranch),
      state.targetBranch == replication.target
    else { throw Thrown("Replication preconditions broken") }
    guard
      pipeline.id == state.pipeline.id,
      state.state == "opened"
    else {
      logMessage(.init(message: "Pipeline outdated"))
      return true
    }
    let merge = try replication.makeMerge(branch: state.sourceBranch)
    guard replication.source.isMet(merge.source.name) else {
      logMessage(.init(message: "Replication blocked by configuration"))
      _ = try putState(gitlab.putMrState(parameters: .init(stateEvent: "close")))
      try handleVoid(query.cfg.git.push(remote: pushUrl, delete: merge.supply))
      return true
    }
    let head = try Git.Sha.init(ref: pipeline.sha)
    var message = try renderStencil(query.cfg.makeRenderStencil(merge: merge))
      .or { throw Thrown("Empty commit message") }
    guard
      case nil = try? handleVoid(query.cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork)
      )),
      case ()? = try? handleVoid(query.cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(parent: 1, ref: .make(sha: merge.fork))
      )),
      case merge.fork.ref = try handleLine(query.cfg.git.mergeBase(
        .make(remote: merge.supply),
        .make(sha: head)
      ))
    else {
      logMessage(.init(message: "Replication is in wrong state"))
      _ = try putState(gitlab.putMrState(parameters: .init(stateEvent: "close")))
      try handleVoid(query.cfg.git.push(remote: pushUrl, delete: merge.supply))
      guard let merge = try makeMerge(
        cfg: query.cfg,
        replication: replication,
        branch: merge.supply.name
      ) else {
        logMessage(.init(message: "No commits to replicate"))
        try handleVoid(query.cfg.git.push(remote: pushUrl, delete: merge.target))
        return true
      }
      let sha = try commitMerge(
        cfg: query.cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: merge.fork
      ) ?? merge.fork
      try handleVoid(query.cfg.git.make(push: .init(
        url: pushUrl,
        branch: merge.supply,
        sha: sha,
        force: false
      )))
      _ = try postMergeRequests(gitlab.postMergeRequests(parameters: .init(
        sourceBranch: merge.supply.name,
        targetBranch: merge.target.name,
        title: message
      )))
      return true
    }
    guard pipeline.user.username == gitlab.botLogin else {
      let squash = try commitMerge(
        cfg: query.cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: head
      ) ?? squashSupply(
        cfg: query.cfg,
        merge: merge,
        message: message,
        sha: head
      )
      _ = try putState(gitlab.putMrState(
        parameters: .init(stateEvent: "close")
      ))
      try handleVoid(query.cfg.git.make(push: .init(
        url: pushUrl,
        branch: merge.supply,
        sha: squash,
        force: true
      )))
      _ = try postMergeRequests(gitlab.postMergeRequests(parameters: .init(
        sourceBranch: merge.supply.name,
        targetBranch: merge.target.name,
        title: message
      )))
      return true
    }
    let parrents = try Id(head)
      .map(Git.Ref.make(sha:))
      .map(query.cfg.git.getParrents(ref:))
      .map(handleLine)
      .get()
      .components(separatedBy: .newlines)
    let target = try handleLine(query.cfg.git.getSha(ref: .make(remote: merge.target)))
    guard [target, merge.fork.ref] == parrents else {
      if let sha = try commitMerge(
        cfg: query.cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: head
      ) {
        try handleVoid(query.cfg.git.make(push: .init(
          url: pushUrl,
          branch: merge.supply,
          sha: sha,
          force: true
        )))
      } else {
        logMessage(.init(message: "Replications stopped due to conflicts"))
        try sendReport(.init(cfg: query.cfg, report: .replicationConflicts(
          .make(cfg: query.cfg, merge: merge)
        )))
      }
      return true
    }
    guard try checkAcceptIssues(cfg: query.cfg, state: state, pipeline: pipeline) else { return true }
    let result = try putMerge(gitlab.putMrMerge(parameters: .init(
      mergeCommitMessage: message,
      squash: false,
      shouldRemoveSourceBranch: true,
      sha: head
    )))
    if case "merged"? = result.map?["state"]?.value?.string {
      logMessage(.init(message: "Review merged"))
      try sendReport(.init(cfg: query.cfg, report: .review(state, .accepted)))
    } else if let message = result.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      try sendReport(.init(cfg: query.cfg, report: .review(state, .mergeError(message))))
      return true
    } else {
      throw MayDay("Accept review responce not handled")
    }
    try handleVoid(query.cfg.git.fetch)
    guard let merge = try makeMerge(
      cfg: query.cfg,
      replication: replication,
      branch: merge.source.name
    ) else {
      logMessage(.init(message: "No commits to replicate"))
      return true
    }
    message = try renderStencil(query.cfg.makeRenderStencil(merge: merge))
      .or { throw Thrown("Empty commit message") }
    let sha = try commitMerge(
      cfg: query.cfg,
      into: .make(remote: merge.target),
      message: message,
      sha: merge.fork
    ) ?? merge.fork
    try handleVoid(query.cfg.git.make(push: .init(
      url: pushUrl,
      branch: merge.supply,
      sha: sha,
      force: false
    )))
    return true
  }
}
extension Laborer {
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
    let initial = try Git.Ref.make(sha: .init(ref: handleLine(git.getSha(ref: .head))))
    let base = try handleLine(git.mergeBase(.make(remote: merge.target), sha))
    try handleVoid(git.detach(to: .make(sha: .init(ref: base))))
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
    let parents = try handleLine(cfg.git.listParents(ref: .make(sha: sha)))
      .components(separatedBy: .whitespaces)
    switch parents.count {
    case 1:
      return try listShaMergeRequests(gitlab.listShaMergeRequests(sha: sha))
        .first { $0.squashCommitSha == sha.ref }
        .map(\.author.username)
    case 2:
      return try resolveOriginalAuthor(cfg: cfg, gitlab: gitlab, sha: .init(ref: parents.end))
    default:
      throw Thrown("\(sha.ref) has \(parents.count) parents")
    }
  }
  func checkAcceptIssues(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    pipeline: Json.GitlabPipeline
  ) throws -> Bool {
    var issues: [String] = []
    if state.draft { issues.append("MR is draft") }
    if state.workInProgress { issues.append("MR is work in progress") }
    if !state.blockingDiscussionsResolved { issues.append("MR has blocking discussions") }
    if pipeline.status != "success" { issues.append("Pipeline status: \(pipeline.status)") }
    guard issues.isEmpty else { return true }
    issues
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    try Id(issues)
      .map(Report.Review.issues(_:))
      .reduce(state, Report.review(_:_:))
      .reduce(cfg, SendReport.init(cfg:report:))
      .map(sendReport)
      .get()
    return false
  }
  func makeMerge(
    cfg: Configuration,
    replication: Configuration.Replication,
    branch: String
  ) throws -> Configuration.Merge? { try Id
    .make(.init(
      include: [.make(remote: .init(name: branch))],
      exclude: [.make(remote: .init(name: replication.target))],
      noMerges: false,
      firstParrents: true
    ))
    .map(cfg.git.make(listCommits:))
    .map(handleLine)
    .get()
    .components(separatedBy: .newlines)
    .last
    .reduce(branch, replication.makeMerge(source:sha:))
  }
  func makeMerge(
    cfg: Configuration,
    integration: Configuration.Integration,
    branch: String
  ) throws -> Configuration.Merge? {
    try integration.makeMerge(
      target: branch,
      source: cfg.get(env: Gitlab.commitBranch),
      sha: handleLine(cfg.git.getSha(ref: .make(remote: .init(name: branch))))
    )
  }
  func commitMerge(
    cfg: Configuration,
    into ref: Git.Ref,
    message: String,
    sha: Git.Sha
  ) throws -> Git.Sha? {
    let initial = try Git.Ref.make(sha: .init(ref: handleLine(cfg.git.getSha(ref: .head))))
    let sha = Git.Ref.make(sha: sha)
    try handleVoid(cfg.git.detach(to: ref))
    try handleVoid(cfg.git.clean)
    do {
      try handleVoid(cfg.git.make(merge: .init(
        ref: sha,
        message: message,
        noFf: true,
        env: Git.makeEnvironment(
          authorName: handleLine(cfg.git.getAuthorName(ref: sha)),
          authorEmail: handleLine(cfg.git.getAuthorEmail(ref: sha))
        )
      )))
    } catch {
      try handleVoid(cfg.git.quitMerge)
      try handleVoid(cfg.git.resetHard(ref: initial))
      try handleVoid(cfg.git.clean)
      return nil
    }
    return try .init(ref: handleLine(cfg.git.getSha(ref: .head)))
  }
  func squashSupply(
    cfg: Configuration,
    merge: Configuration.Merge,
    message: String,
    sha: Git.Sha
  ) throws -> Git.Sha {
    let sha = Git.Ref.make(sha: sha)
    let base = try handleLine(cfg.git.mergeBase(.make(remote: merge.target), sha))
    return try .init(ref: handleLine(cfg.git.make(commitTree: .init(
      tree: sha.tree,
      message: message,
      parrents: [.make(sha: .init(ref: base)), .make(sha: merge.fork)],
      env: Git.makeEnvironment(
        authorName: handleLine(cfg.git.getAuthorName(ref: sha)),
        authorEmail: handleLine(cfg.git.getAuthorEmail(ref: sha))
      )
    ))))
  }
}
