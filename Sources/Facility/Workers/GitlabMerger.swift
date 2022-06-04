import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabMerger {
  let getReviewState: Try.Reply<Gitlab.GetMrState>
  let getPipeline: Try.Reply<Gitlab.GetPipeline>
  let postPipelines: Try.Reply<Gitlab.PostMrPipelines>
  let putMerge: Try.Reply<Gitlab.PutMrMerge>
  let postMergeRequests: Try.Reply<Gitlab.PostMergeRequests>
  let putState: Try.Reply<Gitlab.PutMrState>
  let handleVoid: Try.Reply<Git.HandleVoid>
  let handleLine: Try.Reply<Git.HandleLine>
  let printLine: Act.Of<String>.Go
  let renderStencil: Try.Reply<RenderStencil>
  let resolveGitlab: Try.Reply<ResolveGitlab>
  let sendReport: Try.Reply<SendReport>
  let logMessage: Act.Reply<LogMessage>
  public init(
    getReviewState: @escaping Try.Reply<Gitlab.GetMrState>,
    getPipeline: @escaping Try.Reply<Gitlab.GetPipeline>,
    postPipelines: @escaping Try.Reply<Gitlab.PostMrPipelines>,
    putMerge: @escaping Try.Reply<Gitlab.PutMrMerge>,
    postMergeRequests: @escaping Try.Reply<Gitlab.PostMergeRequests>,
    putState: @escaping Try.Reply<Gitlab.PutMrState>,
    handleVoid: @escaping Try.Reply<Git.HandleVoid>,
    handleLine: @escaping Try.Reply<Git.HandleLine>,
    printLine: @escaping Act.Of<String>.Go,
    renderStencil: @escaping Try.Reply<RenderStencil>,
    resolveGitlab: @escaping Try.Reply<ResolveGitlab>,
    sendReport: @escaping Try.Reply<SendReport>,
    logMessage: @escaping Act.Reply<LogMessage>
  ) {
    self.getReviewState = getReviewState
    self.getPipeline = getPipeline
    self.postPipelines = postPipelines
    self.putMerge = putMerge
    self.postMergeRequests = postMergeRequests
    self.putState = putState
    self.handleVoid = handleVoid
    self.handleLine = handleLine
    self.printLine = printLine
    self.renderStencil = renderStencil
    self.resolveGitlab = resolveGitlab
    self.sendReport = sendReport
    self.logMessage = logMessage
  }
  public func acceptReview(cfg: Configuration) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let state = try getReviewState(gitlab.getParentMrState())
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    guard pipeline.id == state.pipeline.id, state.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return true
    }
    guard try cfg.get(env: Gitlab.commitBranch) == state.targetBranch else {
      logMessage(.init(message: "Target branch changed"))
      _ = try postPipelines(gitlab.postParentMrPipelines())
      return true
    }
    guard try checkAcceptIssues(cfg: cfg, state: state, pipeline: pipeline) else { return true }
    let head = try Git.Sha(ref: state.pipeline.sha)
    let target = try Git.Ref.make(remote: .init(name: state.targetBranch))
    let message = try cfg.review
      .flatMap(\.messageTemplate)
      .reduce(Report.Context.make(review: state), cfg.makeRenderStencil(context:template:))
      .flatMap(renderStencil)
      .or { throw Thrown("Commit message is empty") }
    guard case ()? = try? handleVoid(cfg.git.check(
      child: .make(sha: head),
      parent: target
    )) else {
      if let sha = try commitMerge(
        cfg: cfg,
        into: target,
        message: message,
        sha: head
      ) {
        logMessage(.init(message: "Review was rebased"))
        try handleVoid(cfg.git.make(push: .init(
          url: gitlab.makePushUrl(),
          branch: .init(name: state.sourceBranch),
          sha: sha,
          force: true
        )))
      } else {
        logMessage(.init(message: "Automatic rebase failed"))
        try sendReport(.init(cfg: cfg, report: .review(state, .mergeConflicts)))
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
      try sendReport(.init(cfg: cfg, report: .review(state, .accepted)))
      return true
    } else if let message = result.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      try sendReport(.init(cfg: cfg, report: .review(state, .mergeError(message))))
      return true
    } else {
      throw MayDay("Accept review responce not handled")
    }
  }
  public func startIntegration(cfg: Configuration, target: String) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let integration = try cfg.getIntegration()
    let pushUrl = try gitlab.makePushUrl()
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    let merge = try integration.makeMerge(target: target, source: pipeline.ref, sha: pipeline.sha)
    guard integration.rules.contains(where: { rule in
      rule.mainatiners.contains(gitlab.user)
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
  public func finishIntegration(cfg: Configuration) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let integration = try cfg.getIntegration()
    let pushUrl = try gitlab.makePushUrl()
    let state = try getReviewState(gitlab.getParentMrState())
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    guard
      pipeline.id == state.pipeline.id,
      state.state == "opened"
    else {
      logMessage(.init(message: "Pipeline outdated"))
      return true
    }
    let merge = try integration.makeMerge(branch: state.sourceBranch)
    guard
      case state.targetBranch = try cfg.get(env: Gitlab.commitBranch),
      state.targetBranch == merge.target.name
    else { throw Thrown("Integration preconditions broken") }
    guard integration.rules.contains(where: { rule in
      rule.target.isMet(merge.target.name) && rule.source.isMet(merge.source.name)
    }) else {
      logMessage(.init(message: "Integration blocked by configuration"))
      _ = try putState(gitlab.putMrState(parameters: .init(stateEvent: "close")))
      try handleVoid(cfg.git.push(remote: pushUrl, delete: merge.supply))
      return true
    }
    let head = try Git.Sha(ref: pipeline.sha)
    guard case nil = try? handleVoid(cfg.git.check(
      child: .make(sha: merge.fork),
      parent: .make(remote: merge.target)
    )) else {
      guard pipeline.sha == merge.fork.ref else {
        logMessage(.init(message: "Integration in wrong state"))
        try handleVoid(cfg.git.make(push: .init(
          url: pushUrl,
          branch: merge.supply,
          sha: merge.fork,
          force: true
        )))
        return true
      }
      guard try checkAcceptIssues(cfg: cfg, state: state, pipeline: pipeline) else {
        return false
      }
      let result = try putMerge(gitlab.putMrMerge(parameters: .init(
        squash: false,
        shouldRemoveSourceBranch: true,
        sha: head
      )))
      if case "merged"? = result.map?["state"]?.value?.string {
        logMessage(.init(message: "Review merged"))
        try sendReport(.init(cfg: cfg, report: .review(state, .accepted)))
        return true
      } else if let message = result.map?["message"]?.value?.string {
        logMessage(.init(message: message))
        try sendReport(.init(cfg: cfg, report: .review(state, .mergeError(message))))
        return false
      } else {
        throw MayDay("Accept review responce not handled")
      }
    }
    guard case nil = try? handleVoid(cfg.git.check(
      child: .make(remote: merge.target),
      parent: .make(sha: merge.fork)
    )) else {
      logMessage(.init(message: "\(merge.target.name) already contains \(merge.fork.ref)"))
      _ = try putState(gitlab.putMrState(parameters: .init(stateEvent: "close")))
      try handleVoid(cfg.git.push(remote: pushUrl, delete: merge.supply))
      return true
    }
    guard case merge.fork.ref = try handleLine(cfg.git.mergeBase(
      .make(remote: merge.source),
      .make(sha: head)
    )) else {
      logMessage(.init(message: "Integration is in wrong state"))
      _ = try putState(gitlab.putMrState(parameters: .init(stateEvent: "close")))
      let message = try renderStencil(cfg.makeRenderStencil(merge: merge))
        .or { throw Thrown("Empty commit message") }
      let sha = try commitMerge(
        cfg: cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: merge.fork
      ) ?? merge.fork
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
    guard pipeline.user.username == gitlab.botLogin else {
      let message = try renderStencil(cfg.makeRenderStencil(merge: merge))
        .or { throw Thrown("Empty commit message") }
      let sha = try commitMerge(
        cfg: cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: head
      ) ?? squashSupply(
        cfg: cfg,
        merge: merge,
        message: message,
        sha: head
      )
      _ = try putState(gitlab.putMrState(
        parameters: .init(stateEvent: "close")
      ))
      try handleVoid(cfg.git.make(push: .init(
        url: pushUrl,
        branch: merge.supply,
        sha: sha,
        force: true
      )))
      _ = try postMergeRequests(gitlab.postMergeRequests(parameters: .init(
        sourceBranch: merge.supply.name,
        targetBranch: merge.target.name,
        title: message
      )))
      return true
    }
    let parrents = try handleLine(cfg.git.listParrents(ref: .make(sha: head)))
      .components(separatedBy: .newlines)
    let target = try handleLine(cfg.git.getSha(ref: .make(remote: merge.target)))
    guard [target, merge.fork.ref] == parrents else {
      let message = try renderStencil(cfg.makeRenderStencil(merge: merge))
        .or { throw Thrown("Empty commit message") }
      if let sha = try commitMerge(
        cfg: cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: head
      ) {
        try handleVoid(cfg.git.make(push: .init(
          url: pushUrl,
          branch: merge.supply,
          sha: sha,
          force: true
        )))
      } else {
        logMessage(.init(message: "Integration stopped due to conflicts"))
        try sendReport(.init(cfg: cfg, report: .replicationConflicts(
          .make(cfg: cfg, merge: merge)
        )))
      }
      return true
    }
    guard try checkAcceptIssues(cfg: cfg, state: state, pipeline: pipeline) else {
      return false
    }
    let result = try putMerge(gitlab.putMrMerge(parameters: .init(
      squash: false,
      shouldRemoveSourceBranch: true,
      sha: head
    )))
    if case "merged"? = result.map?["state"]?.value?.string {
      logMessage(.init(message: "Review merged"))
      try sendReport(.init(cfg: cfg, report: .review(state, .accepted)))
      return true
    } else if let message = result.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      try sendReport(.init(cfg: cfg, report: .review(state, .mergeError(message))))
      return false
    } else {
      throw MayDay("Accept review responce not handled")
    }
  }
  public func renderIntegration(cfg: Configuration) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    let fork = try Git.Sha(ref: pipeline.sha)
    let source = try Git.Branch(name: pipeline.ref)
    let rules = try cfg.getIntegration().rules
      .filter { $0.source.isMet(source.name) }
      .mapEmpty { throw Thrown("Integration for \(source.name) not configured") }
    var targets: [Git.Branch] = []
    for line in try handleLine(cfg.git.listLocalRefs).components(separatedBy: .newlines) {
      let pair = line.components(separatedBy: .whitespaces)
      guard pair.count == 2 else { throw MayDay("bad git reply") }
      guard let target = try? pair[1].dropPrefix("refs/remotes/origin/") else { continue }
      guard rules.contains(where: { $0.target.isMet(target) }) else { continue }
      let sha = try Git.Sha.init(ref: pair[0])
      guard case nil = try? handleVoid(cfg.git.check(
        child: .make(sha: sha),
        parent: .make(sha: fork)
      )) else { continue }
      try targets.append(.init(name: target))
    }
    guard !targets.isEmpty else { throw Thrown("No branches suitable for integration") }
    var result = ["include: $\(Gitlab.configPath)"]
    for target in targets {
      result += try renderStencil(cfg.makeRenderIntegrationJob(target: target.name))
        .or { throw Thrown("Rendered job is empty") }
        .components(separatedBy: .newlines)
    }
    result.forEach(printLine)
    return true
  }
  public func startReplication(cfg: Configuration) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let replication = try cfg.getReplication()
    let branch = try cfg.get(env: Gitlab.commitBranch)
    guard replication.source.isMet(branch) else {
      logMessage(.init(message: "Replication blocked by configuration"))
      return true
    }
    guard let merge = try makeMerge(
      cfg: cfg,
      replication: replication,
      branch: branch
    ) else {
      logMessage(.init(message: "No commits to replicate"))
      return true
    }
    guard case nil = try? handleLine(cfg.git.checkRefType(
      ref: .make(remote: merge.supply)
    )) else {
      logMessage(.init(message: "Replication already in progress"))
      return true
    }
    let message = try renderStencil(cfg.makeRenderStencil(merge: merge))
      .or { throw Thrown("Empty commit message") }
    let sha = try commitMerge(
      cfg: cfg,
      into: .make(remote: merge.target),
      message: message,
      sha: merge.fork
    ) ?? merge.fork
    try handleVoid(cfg.git.make(push: .init(
      url: gitlab.makePushUrl(),
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
  public func updateReplication(cfg: Configuration) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let replication = try cfg.getReplication()
    let pushUrl = try gitlab.makePushUrl()
    let state = try getReviewState(gitlab.getParentMrState())
    let pipeline = try getPipeline(gitlab.getParentPipeline())
    guard
      pipeline.id == state.pipeline.id,
      state.state == "opened"
    else {
      logMessage(.init(message: "Pipeline outdated"))
      return true
    }
    guard
      case state.targetBranch = try cfg.get(env: Gitlab.commitBranch),
      state.targetBranch == replication.target
    else { throw Thrown("Replication preconditions broken") }
    let merge = try replication.makeMerge(branch: state.sourceBranch)
    guard replication.source.isMet(merge.source.name) else {
      logMessage(.init(message: "Replication blocked by configuration"))
      _ = try putState(gitlab.putMrState(parameters: .init(stateEvent: "close")))
      try handleVoid(cfg.git.push(remote: pushUrl, delete: merge.supply))
      return true
    }
    let head = try Git.Sha.init(ref: pipeline.sha)
    guard
      case nil = try? handleVoid(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork)
      )),
      case ()? = try? handleVoid(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(parent: 1, ref: .make(sha: merge.fork))
      )),
      case merge.fork.ref = try handleLine(cfg.git.mergeBase(
        .make(remote: merge.source),
        .make(sha: head)
      ))
    else {
      logMessage(.init(message: "Replication is in wrong state"))
      _ = try putState(gitlab.putMrState(parameters: .init(stateEvent: "close")))
      try handleVoid(cfg.git.push(remote: pushUrl, delete: merge.supply))
      guard let merge = try makeMerge(
        cfg: cfg,
        replication: replication,
        branch: merge.supply.name
      ) else {
        logMessage(.init(message: "No commits to replicate"))
        return true
      }
      let message = try renderStencil(cfg.makeRenderStencil(merge: merge))
        .or { throw Thrown("Empty commit message") }
      let sha = try commitMerge(
        cfg: cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: merge.fork
      ) ?? merge.fork
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
    guard pipeline.user.username == gitlab.botLogin else {
      let message = try renderStencil(cfg.makeRenderStencil(merge: merge))
        .or { throw Thrown("Empty commit message") }
      let sha = try commitMerge(
        cfg: cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: head
      ) ?? squashSupply(
        cfg: cfg,
        merge: merge,
        message: message,
        sha: head
      )
      _ = try putState(gitlab.putMrState(
        parameters: .init(stateEvent: "close")
      ))
      try handleVoid(cfg.git.make(push: .init(
        url: pushUrl,
        branch: merge.supply,
        sha: sha,
        force: true
      )))
      _ = try postMergeRequests(gitlab.postMergeRequests(parameters: .init(
        sourceBranch: merge.supply.name,
        targetBranch: merge.target.name,
        title: message
      )))
      return true
    }
    let parrents = try handleLine(cfg.git.listParrents(ref: .make(sha: head)))
      .components(separatedBy: .newlines)
    let target = try handleLine(cfg.git.getSha(ref: .make(remote: merge.target)))
    guard [target, merge.fork.ref] == parrents else {
      let message = try renderStencil(cfg.makeRenderStencil(merge: merge))
        .or { throw Thrown("Empty commit message") }
      if let sha = try commitMerge(
        cfg: cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: head
      ) {
        try handleVoid(cfg.git.make(push: .init(
          url: pushUrl,
          branch: merge.supply,
          sha: sha,
          force: true
        )))
      } else {
        logMessage(.init(message: "Replications stopped due to conflicts"))
        try sendReport(.init(cfg: cfg, report: .replicationConflicts(
          .make(cfg: cfg, merge: merge)
        )))
      }
      return true
    }
    guard try checkAcceptIssues(cfg: cfg, state: state, pipeline: pipeline) else {
      return false
    }
    let result = try putMerge(gitlab.putMrMerge(parameters: .init(
      squash: false,
      shouldRemoveSourceBranch: true,
      sha: head
    )))
    if case "merged"? = result.map?["state"]?.value?.string {
      logMessage(.init(message: "Review merged"))
      try sendReport(.init(cfg: cfg, report: .review(state, .accepted)))
    } else if let message = result.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      try sendReport(.init(cfg: cfg, report: .review(state, .mergeError(message))))
      return false
    } else {
      throw MayDay("Accept review responce not handled")
    }
    try handleVoid(cfg.git.fetch)
    guard let merge = try makeMerge(
      cfg: cfg,
      replication: replication,
      branch: merge.source.name
    ) else {
      logMessage(.init(message: "No commits to replicate"))
      return true
    }
    let message = try renderStencil(cfg.makeRenderStencil(merge: merge))
      .or { throw Thrown("Empty commit message") }
    let sha = try commitMerge(
      cfg: cfg,
      into: .make(remote: merge.target),
      message: message,
      sha: merge.fork
    ) ?? merge.fork
    try handleVoid(cfg.git.make(push: .init(
      url: pushUrl,
      branch: merge.supply,
      sha: sha,
      force: false
    )))
    return true
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
