import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabMerger {
  let handleApi: Try.Reply<GitlabCi.HandleApi>
  let handleVoid: Try.Reply<Git.HandleVoid>
  let handleLine: Try.Reply<Git.HandleLine>
  let resolveFlow: Try.Reply<ResolveFlow>
  let printLine: Act.Of<String>.Go
  let renderStencil: Try.Reply<RenderStencil>
  let sendReport: Try.Reply<SendReport>
  let logMessage: Act.Reply<LogMessage>
  let dialect: AnyCodable.Dialect
  public init(
    handleApi: @escaping Try.Reply<GitlabCi.HandleApi>,
    handleVoid: @escaping Try.Reply<Git.HandleVoid>,
    handleLine: @escaping Try.Reply<Git.HandleLine>,
    resolveFlow: @escaping Try.Reply<ResolveFlow>,
    printLine: @escaping Act.Of<String>.Go,
    renderStencil: @escaping Try.Reply<RenderStencil>,
    sendReport: @escaping Try.Reply<SendReport>,
    logMessage: @escaping Act.Reply<LogMessage>,
    dialect: AnyCodable.Dialect
  ) {
    self.handleApi = handleApi
    self.handleVoid = handleVoid
    self.handleLine = handleLine
    self.resolveFlow = resolveFlow
    self.printLine = printLine
    self.renderStencil = renderStencil
    self.sendReport = sendReport
    self.logMessage = logMessage
    self.dialect = dialect
  }
  public func validateReviewTitle(cfg: Configuration, title: String) throws -> Bool {
    let titleRule = try resolveFlow(.init(cfg: cfg))
      .squash
      .flatMap(\.titleRule)
      .get()
    guard titleRule.isMet(title) else { return true }
    try sendReport(cfg.makeSendReport(report: cfg.reportInvalidTitle(
      job: cfg.controls.gitlabCi
        .flatMap(\.getCurrentJob)
        .map(handleApi)
        .reduce(Json.GitlabJob.self, dialect.read(_:from:))
        .get(),
      title: title
    )))
    return false
  }
  public func validateReviewStatus(cfg: Configuration) throws -> Bool {
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
    var reasons: [Report.ReviewBlocked.Reason] = []
    if review.draft { reasons.append(.draft) }
    if review.workInProgress { reasons.append(.workInProgress) }
    if !review.blockingDiscussionsResolved { reasons.append(.blockingDiscussions) }
    guard reasons.isEmpty else { return true }
    try sendReport(cfg.makeSendReport(report: cfg.reportReviewBlocked(
      review: review,
      users: [review.author.username],
      reasons: reasons
    )))
    return false
  }
  public func acceptReview(cfg: Configuration) throws -> Bool {
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
    let head = try Git.Sha(value: review.pipeline.sha)
    let target = try Git.Ref.make(remote: .init(name: review.targetBranch))
    let squash = try resolveFlow(.init(cfg: cfg)).squash.get()
    let message = try renderStencil(.make(generator: cfg.generateSquashCommitMessage(
      squash: squash,
      review: review
    )))
    let targetSha = try handleLine(cfg.git.getSha(ref: target))
    let headParent = try handleLine(cfg.git.getSha(ref: .make(sha: head).make(parent: 1)))
    guard targetSha == headParent else {
      if let sha = try commitMerge(
        cfg: cfg,
        into: target,
        message: message,
        sha: head
      ) {
        logMessage(.init(message: "Review was updated"))
        try handleVoid(cfg.git.make(push: .init(
          url: gitlabCi.pushUrl.get(),
          branch: .init(name: review.sourceBranch),
          sha: sha,
          force: true
        )))
      } else {
        logMessage(.init(message: "Automatic merge failed"))
        try sendReport(cfg.makeSendReport(report: cfg.reportReviewMergeConflicts(
          review: review,
          users: [review.author.username]
        )))
      }
      return false
    }
    return try acceptMerge(
      cfg: cfg,
      gitlabCi: gitlabCi,
      review: review,
      message: message,
      sha: head,
      users: []
    )
  }
  public func startIntegration(cfg: Configuration, target: String) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let integration = try resolveFlow(.init(cfg: cfg)).integration.get()
    let job = try gitlabCi.getCurrentJob
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
      .get()
    guard !job.tag else { throw Thrown("Not on branch") }
    let merge = try integration.makeMerge(
      target: target, source: job.pipeline.ref,
      sha: job.pipeline.sha
    )
    guard integration.rules.contains(where: { rule in
      rule.mainatiners.contains(job.user.username)
      && rule.target.isMet(merge.target.name)
      && rule.source.isMet(merge.source.name)
    }) else { throw Thrown("Integration not allowed for \(job.user.username)") }
    guard checkNeeded(cfg: cfg, merge: merge) else { return true }
    guard case nil = try? handleLine(cfg.git.checkRefType(
      ref: .make(remote: merge.supply)
    )) else { throw Thrown("Integration already in progress") }
    let message = try renderStencil(.make(generator: cfg.generateIntegrationCommitMessage(
      integration: integration,
      merge: merge
    )))
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
      url: gitlabCi.pushUrl.get(),
      branch: merge.supply,
      sha: sha,
      force: false
    )))
    _ = try gitlabCi
      .postMergeRequests(parameters: .init(
        sourceBranch: merge.supply.name,
        targetBranch: merge.target.name,
        title: message
      ))
      .map(handleApi)
      .get()
    return true
  }
  public func finishIntegration(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let integration = try resolveFlow(.init(cfg: cfg)).integration.get()
    let job = try gitlabCi.getCurrentJob
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
      .get()
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
      return true
    }
    let merge = try integration.makeMerge(supply: review.sourceBranch)
    guard
      case review.targetBranch = job.pipeline.ref,
      review.targetBranch == merge.target.name
    else { throw Thrown("Integration preconditions broken") }
    guard integration.rules.contains(where: { rule in
      rule.target.isMet(merge.target.name) && rule.source.isMet(merge.source.name)
    }) else {
      logMessage(.init(message: "Integration blocked by configuration"))
      _ = try gitlabCi
        .putMrState(parameters: .init(stateEvent: "close"))
        .map(handleApi)
        .get()
      try handleVoid(cfg.git.push(remote: gitlabCi.pushUrl.get(), delete: merge.supply))
      return true
    }
    let head = try Git.Sha(value: pipeline.sha)
    guard case nil = try? handleVoid(cfg.git.check(
      child: .make(sha: merge.fork),
      parent: .make(remote: merge.target)
    )) else {
      guard pipeline.sha == merge.fork.value else {
        logMessage(.init(message: "Wrong integration state"))
        try handleVoid(cfg.git.make(push: .init(
          url: gitlabCi.pushUrl.get(),
          branch: merge.supply,
          sha: merge.fork,
          force: true
        )))
        return true
      }
      return try acceptMerge(
        cfg: cfg,
        gitlabCi: gitlabCi,
        review: review,
        message: nil,
        sha: head,
        users: resolveParticipants(cfg: cfg, gitlabCi: gitlabCi, merge: merge)
      )
    }
    guard checkNeeded(cfg: cfg, merge: merge) else {
      _ = try gitlabCi
        .putMrState(parameters: .init(stateEvent: "close"))
        .map(handleApi)
        .get()
      try handleVoid(cfg.git.push(remote: gitlabCi.pushUrl.get(), delete: merge.supply))
      return true
    }
    guard case merge.fork.value = try handleLine(cfg.git.mergeBase(
      .make(remote: merge.source),
      .make(sha: head)
    )) else {
      logMessage(.init(message: "Integration is in wrong state"))
      _ = try gitlabCi
        .putMrState(parameters: .init(stateEvent: "close"))
        .map(handleApi)
        .get()
      let message = try renderStencil(.make(generator: cfg.generateIntegrationCommitMessage(
        integration: integration,
        merge: merge
      )))
      let sha = try commitMerge(
        cfg: cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: merge.fork
      ) ?? merge.fork
      try handleVoid(cfg.git.make(push: .init(
        url: gitlabCi.pushUrl.get(),
        branch: merge.supply,
        sha: sha,
        force: false
      )))
      _ = try gitlabCi
        .postMergeRequests(parameters: .init(
          sourceBranch: merge.supply.name,
          targetBranch: merge.target.name,
          title: message
        ))
        .map(handleApi)
        .get()
      return true
    }
    guard pipeline.user.username == gitlabCi.botLogin else {
      let message = try renderStencil(.make(generator: cfg.generateIntegrationCommitMessage(
        integration: integration,
        merge: merge
      )))
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
      _ = try gitlabCi
        .putMrState(parameters: .init(stateEvent: "close"))
        .map(handleApi)
        .get()
      try handleVoid(cfg.git.make(push: .init(
        url: gitlabCi.pushUrl.get(),
        branch: merge.supply,
        sha: sha,
        force: true
      )))
      _ = try gitlabCi
        .postMergeRequests(parameters: .init(
          sourceBranch: merge.supply.name,
          targetBranch: merge.target.name,
          title: message
        ))
        .map(handleApi)
        .get()
      return true
    }
    let parents = try handleLine(cfg.git.listParents(ref: .make(sha: head)))
      .components(separatedBy: .newlines)
    let target = try handleLine(cfg.git.getSha(ref: .make(remote: merge.target)))
    guard [target, merge.fork.value] == parents else {
      let message = try renderStencil(.make(generator: cfg.generateIntegrationCommitMessage(
        integration: integration,
        merge: merge
      )))
      if let sha = try commitMerge(
        cfg: cfg,
        into: .make(remote: merge.target),
        message: message,
        sha: head
      ) {
        try handleVoid(cfg.git.make(push: .init(
          url: gitlabCi.pushUrl.get(),
          branch: merge.supply,
          sha: sha,
          force: true
        )))
      } else {
        logMessage(.init(message: "Integration stopped due to conflicts"))
        try sendReport(cfg.makeSendReport(report: cfg.reportReviewMergeConflicts(
          review: review,
          users: resolveParticipants(cfg: cfg, gitlabCi: gitlabCi, merge: merge)
        )))
      }
      return false
    }
    return try acceptMerge(
      cfg: cfg,
      gitlabCi: gitlabCi,
      review: review,
      message: nil,
      sha: head,
      users: resolveParticipants(cfg: cfg, gitlabCi: gitlabCi, merge: merge)
    )
  }
  public func renderIntegration(cfg: Configuration, template: String) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let pipeline = try gitlabCi.parent.pipeline
      .flatMap(gitlabCi.getPipeline(pipeline:))
      .map(handleApi)
      .reduce(Json.GitlabPipeline.self, dialect.read(_:from:))
      .get()
    let fork = try Git.Sha(value: pipeline.sha)
    let source = try Git.Branch(name: pipeline.ref)
    let integration = try resolveFlow(.init(cfg: cfg)).integration.get()
    let rules = try integration.rules
      .filter { $0.source.isMet(source.name) }
      .mapEmpty { throw Thrown("Integration for \(source.name) not configured") }
    var targets: [Git.Branch] = []
    for line in try handleLine(cfg.git.listLocalRefs).components(separatedBy: .newlines) {
      let pair = line.components(separatedBy: .whitespaces)
      guard pair.count == 2 else { throw MayDay("bad git reply") }
      guard let target = try? pair[1].dropPrefix("refs/remotes/origin/") else { continue }
      guard rules.contains(where: { $0.target.isMet(target) }) else { continue }
      let sha = try Git.Sha.init(value: pair[0])
      guard case nil = try? handleVoid(cfg.git.check(
        child: .make(sha: sha),
        parent: .make(sha: fork)
      )) else { continue }
      try targets.append(.init(name: target))
    }
    guard !targets.isEmpty else { throw Thrown("No branches suitable for integration") }
    try printLine(renderStencil(.make(generator: cfg.generateIntegration(
      template: template,
      targets: targets
        .map(\.name)
    ))))
    return true
  }
  public func startReplication(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let replication = try resolveFlow(.init(cfg: cfg)).replication.get()
    let job = try gitlabCi.getCurrentJob
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
      .get()
    guard !job.tag else { throw Thrown("Not on branch") }
    guard replication.source.isMet(job.pipeline.ref) else {
      logMessage(.init(message: "Replication blocked by configuration"))
      return true
    }
    guard let merge = try makeMerge(
      cfg: cfg,
      replication: replication,
      source: job.pipeline.ref
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
    let message = try renderStencil(.make(generator: cfg.generateReplicationCommitMessage(
      replication: replication,
      merge: merge
    )))
    let sha = try commitMerge(
      cfg: cfg,
      into: .make(remote: merge.target),
      message: message,
      sha: merge.fork
    ) ?? merge.fork
    try handleVoid(cfg.git.make(push: .init(
      url: gitlabCi.pushUrl.get(),
      branch: merge.supply,
      sha: sha,
      force: false
    )))
    _ = try gitlabCi
      .postMergeRequests(parameters: .init(
        sourceBranch: merge.supply.name,
        targetBranch: merge.target.name,
        title: message
      ))
      .map(handleApi)
      .get()
    return true
  }
  public func updateReplication(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let replication = try resolveFlow(.init(cfg: cfg)).replication.get()
    let pushUrl = try gitlabCi.pushUrl.get()
    let job = try gitlabCi.getCurrentJob
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
      .get()
    let review = try gitlabCi.getParentMrState
      .map(handleApi)
      .reduce(Json.GitlabReviewState.self, dialect.read(_:from:))
      .get()
    let pipeline = try gitlabCi.parent.pipeline
      .flatMap(gitlabCi.getPipeline(pipeline:))
      .map(handleApi)
      .reduce(Json.GitlabPipeline.self, dialect.read(_:from:))
      .get()
    guard
      pipeline.id == review.pipeline.id,
      review.state == "opened"
    else {
      logMessage(.init(message: "Pipeline outdated"))
      return true
    }
    guard review.targetBranch == job.pipeline.ref, review.targetBranch == replication.target
    else { throw Thrown("Replication preconditions broken") }
    let merge = try replication.makeMerge(supply: review.sourceBranch)
    guard replication.source.isMet(merge.source.name) else {
      logMessage(.init(message: "Replication blocked by configuration"))
      _ = try gitlabCi
        .putMrState(parameters: .init(stateEvent: "close"))
        .map(handleApi)
        .get()
      try handleVoid(cfg.git.push(remote: pushUrl, delete: merge.supply))
      return true
    }
    let head = try Git.Sha.init(value: pipeline.sha)
    guard
      case nil = try? handleVoid(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork)
      )),
      case ()? = try? handleVoid(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork).make(parent: 1)
      )),
      case merge.fork.value = try handleLine(cfg.git.mergeBase(
        .make(remote: merge.source),
        .make(sha: head)
      ))
    else {
      logMessage(.init(message: "Replication is in wrong state"))
      _ = try gitlabCi
        .putMrState(parameters: .init(stateEvent: "close"))
        .map(handleApi)
        .get()
      try handleVoid(cfg.git.push(remote: pushUrl, delete: merge.supply))
      guard let merge = try makeMerge(
        cfg: cfg,
        replication: replication,
        source: merge.source.name
      ) else {
        logMessage(.init(message: "No commits to replicate"))
        return true
      }
      let message = try renderStencil(.make(generator: cfg.generateReplicationCommitMessage(
        replication: replication,
        merge: merge
      )))
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
      _ = try gitlabCi
        .postMergeRequests(parameters: .init(
          sourceBranch: merge.supply.name,
          targetBranch: merge.target.name,
          title: message
        ))
        .map(handleApi)
        .get()
      return true
    }
    guard pipeline.user.username == gitlabCi.botLogin else {
      let message = try renderStencil(.make(generator: cfg.generateReplicationCommitMessage(
        replication: replication,
        merge: merge
      )))
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
      _ = try gitlabCi
        .putMrState(parameters: .init(stateEvent: "close"))
        .map(handleApi)
        .get()
      try handleVoid(cfg.git.make(push: .init(
        url: pushUrl,
        branch: merge.supply,
        sha: sha,
        force: true
      )))
      _ = try gitlabCi
        .postMergeRequests(parameters: .init(
          sourceBranch: merge.supply.name,
          targetBranch: merge.target.name,
          title: message
        ))
        .map(handleApi)
        .get()
      return true
    }
    let parents = try handleLine(cfg.git.listParents(ref: .make(sha: head)))
      .components(separatedBy: .newlines)
    let target = try handleLine(cfg.git.getSha(ref: .make(remote: merge.target)))
    guard [target, merge.fork.value] == parents else {
      let message = try renderStencil(.make(generator: cfg.generateReplicationCommitMessage(
        replication: replication,
        merge: merge
      )))
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
        try sendReport(cfg.makeSendReport(report: cfg.reportReviewMergeConflicts(
          review: review,
          users: resolveParticipants(cfg: cfg, gitlabCi: gitlabCi, merge: merge)
        )))
      }
      return true
    }
    guard try acceptMerge(
      cfg: cfg,
      gitlabCi: gitlabCi,
      review: review,
      message: nil,
      sha: head,
      users: resolveParticipants(cfg: cfg, gitlabCi: gitlabCi, merge: merge)
    ) else { return false }
    try handleVoid(cfg.git.fetch)
    guard let merge = try makeMerge(
      cfg: cfg,
      replication: replication,
      source: merge.source.name
    ) else {
      logMessage(.init(message: "No commits to replicate"))
      return true
    }
    let message = try renderStencil(.make(generator: cfg.generateReplicationCommitMessage(
      replication: replication,
      merge: merge
    )))
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
  func makeMerge(
    cfg: Configuration,
    replication: Flow.Replication,
    source: String
  ) throws -> Flow.Merge? { try Id
    .make(.init(
      include: [.make(remote: .init(name: source))],
      exclude: [.make(remote: .init(name: replication.target))],
      noMerges: false,
      firstParents: true
    ))
    .map(cfg.git.make(listCommits:))
    .map(handleLine)
    .get()
    .components(separatedBy: .newlines)
    .last
    .reduce(source, replication.makeMerge(source:sha:))
  }
  func commitMerge(
    cfg: Configuration,
    into ref: Git.Ref,
    message: String,
    sha: Git.Sha
  ) throws -> Git.Sha? {
    let initial = try Git.Ref.make(sha: .init(value: handleLine(cfg.git.getSha(ref: .head))))
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
    return try .init(value: handleLine(cfg.git.getSha(ref: .head)))
  }
  func squashSupply(
    cfg: Configuration,
    merge: Flow.Merge,
    message: String,
    sha: Git.Sha
  ) throws -> Git.Sha {
    let sha = Git.Ref.make(sha: sha)
    let base = try handleLine(cfg.git.mergeBase(.make(remote: merge.target), sha))
    return try .init(value: handleLine(cfg.git.make(commitTree: .init(
      tree: sha.tree,
      message: message,
      parents: [.make(sha: .init(value: base)), .make(sha: merge.fork)],
      env: Git.makeEnvironment(
        authorName: handleLine(cfg.git.getAuthorName(ref: sha)),
        authorEmail: handleLine(cfg.git.getAuthorEmail(ref: sha))
      )
    ))))
  }
  func acceptMerge(
    cfg: Configuration,
    gitlabCi: GitlabCi,
    review: Json.GitlabReviewState,
    message: String?,
    sha: Git.Sha,
    users: [String]
  ) throws -> Bool {
    let result = try gitlabCi
      .putMrMerge(parameters: .init(
        mergeCommitMessage: message,
        squash: message != nil,
        shouldRemoveSourceBranch: true,
        sha: sha
      ))
      .map(handleApi)
      .get()
    if case "merged"? = result.map?["state"]?.value?.string {
      logMessage(.init(message: "Review merged"))
      try sendReport(cfg.makeSendReport(report: cfg.reportReviewMerged(
        review: review,
        users: users
      )))
      return true
    } else if let message = result.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      try sendReport(cfg.makeSendReport(report: cfg.reportReviewMergeError(
        review: review,
        users: users,
        error: message
      )))
      return false
    } else {
      throw MayDay("Unexpected merge response")
    }
  }
  func checkNeeded(cfg: Configuration, merge: Flow.Merge) -> Bool {
    guard case ()? = try? handleVoid(cfg.git.check(
      child: .make(remote: merge.target),
      parent: .make(sha: merge.fork)
    )) else { return true }
    logMessage(.init(message: "\(merge.target.name) already contains \(merge.fork.value)"))
    return false
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
