import Foundation
import Facility
import FacilityPure
public final class Merger {
  let execute: Try.Reply<Execute>
  let resolveFusion: Try.Reply<Configuration.ResolveFusion>
  let writeStdout: Act.Of<String>.Go
  let generate: Try.Reply<Generate>
  let report: Act.Reply<Report>
  let logMessage: Act.Reply<LogMessage>
  let worker: Worker
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveFusion: @escaping Try.Reply<Configuration.ResolveFusion>,
    writeStdout: @escaping Act.Of<String>.Go,
    generate: @escaping Try.Reply<Generate>,
    report: @escaping Act.Reply<Report>,
    logMessage: @escaping Act.Reply<LogMessage>,
    worker: Worker,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.resolveFusion = resolveFusion
    self.writeStdout = writeStdout
    self.generate = generate
    self.report = report
    self.logMessage = logMessage
    self.worker = worker
    self.jsonDecoder = jsonDecoder
  }
  public func updateFusion(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    let kind = try fusion.makeKind(supply: ctx.review.sourceBranch)
    if let error = try checkFusionErrors(cfg: cfg, fusion: fusion, kind: kind) {
      try closeReview(cfg: cfg, ctx: ctx)
      throw Thrown(error)
    }
    guard try checkReviewErrors(cfg: cfg, ctx: ctx, fusion: fusion, kind: kind) else {
      return false
    }
    guard try !checkIsRebased(cfg: cfg, ctx: ctx) else { return true }
    if let sha = try rebaseReview(cfg: cfg, ctx: ctx, fusion: fusion) {
      try Execute.checkStatus(reply: execute(cfg.git.push(
        url: ctx.gitlab.pushUrl.get(),
        branch: .init(name: ctx.review.sourceBranch),
        sha: sha,
        force: false
      )))
    } else {
      try report(cfg.reportReviewMergeConflicts(
        review: ctx.review,
        users: worker.resolveParticipants(
          cfg: cfg,
          gitlabCi: ctx.gitlab,
          source: .make(sha: .init(value: ctx.job.pipeline.sha)),
          target: .make(remote: .init(name: ctx.review.targetBranch))
        )
      ))
    }
    return false
  }
  public func acceptFusion(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    let kind = try fusion.makeKind(supply: ctx.review.sourceBranch)
    if let error = try checkFusionErrors(cfg: cfg, fusion: fusion, kind: kind) {
      try closeReview(cfg: cfg, ctx: ctx)
      throw Thrown(error)
    }
    guard try checkReviewErrors(cfg: cfg, ctx: ctx, fusion: fusion, kind: kind) else {
      return false
    }
    guard try checkIsRebased(cfg: cfg, ctx: ctx) else { return false }
    switch kind {
    case .proposition:
      guard try acceptReview(cfg: cfg, ctx: ctx, message: generate(cfg.createPropositionCommitMessage(
        proposition: fusion.proposition,
        review: ctx.review
      ))) else { return false }
    case .replication(let merge):
      guard try acceptReview(cfg: cfg, ctx: ctx, message: generate(cfg.createReplicationCommitMessage(
        replication: fusion.replication,
        merge: merge
      ))) else { return false }
      if let merge = try shiftReplication(cfg: cfg, merge: merge) {
        try createReview(
          cfg: cfg,
          gitlab: ctx.gitlab,
          merge: merge,
          title: generate(cfg.createReplicationCommitMessage(
            replication: fusion.replication,
            merge: merge
          ))
        )
      }
    case .integration(let merge):
      guard try acceptReview(cfg: cfg, ctx: ctx, message: generate(cfg.createIntegrationCommitMessage(
        integration: fusion.integration,
        merge: merge
      ))) else { return false }
    }
    return true
  }
  public func startReplication(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    let parent = try gitlabCi.parent.get()
    let job = try gitlabCi.getJob(id: parent.job)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let fusion = try resolveFusion(.init(cfg: cfg))
    let merge = try fusion.replication.makeMerge(source: job.pipeline.ref, fork: job.pipeline.sha)
    if let error = try checkFusionErrors(cfg: cfg, fusion: fusion, kind: .integration(merge)) {
      logMessage(.init(message: error))
      return false
    }
    try createReview(
      cfg: cfg,
      gitlab: cfg.gitlabCi.get(),
      merge: merge,
      title: generate(cfg.createReplicationCommitMessage(
        replication: fusion.replication,
        merge: merge
      ))
    )
    return true
  }
  public func startIntegration(
    cfg: Configuration,
    source: String,
    target: String,
    fork: String
  ) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let merge = try fusion.integration.makeMerge(target: target, source: source, fork: fork)
    if let error = try checkFusionErrors(cfg: cfg, fusion: fusion, kind: .integration(merge)) {
      logMessage(.init(message: error))
      return false
    }
    try createReview(
      cfg: cfg,
      gitlab: cfg.gitlabCi.get(),
      merge: merge,
      title: generate(cfg.createIntegrationCommitMessage(
        integration: fusion.integration,
        merge: merge
      ))
    )
    return true
  }
  public func renderIntegration(cfg: Configuration) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    let parent = try gitlabCi.parent.get()
    let job = try gitlabCi.getJob(id: parent.job)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let fusion = try resolveFusion(.init(cfg: cfg))
    let fork = try Git.Sha(value: job.pipeline.sha)
    let source = try Git.Branch(name: job.pipeline.ref)
    let rules = try fusion.integration.rules
      .filter { $0.source.isMet(source.name) }
      .mapEmpty { throw Thrown("Integration for \(source.name) not configured") }
    var targets: [String] = []
    for target in try listTrackingBranches(cfg: cfg) {
      guard fusion.targets.isMet(target.name) else { continue }
      guard rules.contains(where: { $0.target.isMet(target.name) }) else { continue }
      guard try !Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: target),
        parent: .make(sha: fork)
      ))) else { continue }
      targets.append(target.name)
    }
    guard !targets.isEmpty else { throw Thrown("No branches suitable for integration") }
    try writeStdout(generate(cfg.exportIntegrationTargets(
      integration: fusion.integration,
      fork: fork,
      source: source.name,
      targets: targets
    )))
    return true
  }
  func checkFusionErrors(
    cfg: Configuration,
    fusion: Fusion,
    kind: Fusion.Kind
  ) throws -> String? {
    switch kind {
    case .proposition: break
    case .replication(let merge):
      guard fusion.targets.isMet(merge.target.name)
      else { return "Target blocked by fusion configuration" }
      guard fusion.replication.source.isMet(merge.source.name)
      else { return "Source blocked by replication configuration" }
      guard merge.target.name == fusion.replication.target
      else { return "Target blocked by replication configuration" }
      guard try !Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork)
      ))) else { return "Replication fork already merged" }
      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork).make(parent: 1)
      ))) else { return "Replication fork parent is not merged" }
    case .integration(let merge):
      guard fusion.targets.isMet(merge.target.name)
      else { return "Target blocked by fusion configuration" }
      guard fusion.integration.rules.contains(where: { rule in
        rule.target.isMet(merge.target.name) && rule.source.isMet(merge.source.name)
      }) else { return "Source or target blocked by integration configuration" }
      guard try !Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork)
      ))) else { return "Integration fork already merged" }
    }
    return nil
  }
  func checkReviewErrors(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    fusion: Fusion,
    kind: Fusion.Kind
  ) throws -> Bool {
    var reasons: [Report.ReviewBlocked.Reason] = []
    if ctx.review.draft { reasons.append(.draft) }
    if ctx.review.workInProgress { reasons.append(.workInProgress) }
    if !ctx.review.blockingDiscussionsResolved { reasons.append(.blockingDiscussions) }
    let excludes: [Git.Ref]
    switch kind {
    case .proposition(let rule):
      if !ctx.review.squash { reasons.append(.squashStatus) }
      if !fusion.targets.isMet(ctx.review.targetBranch) { reasons.append(.badTarget) }
      if let rule = rule {
        if !rule.title.isMet(ctx.review.title) { reasons.append(.badTitle) }
      } else { reasons.append(.configuration) }
      try excludes = [.make(remote: .init(name: ctx.review.targetBranch))]
    case .replication(let merge), .integration(let merge):
      if ctx.review.squash { reasons.append(.squashStatus) }
      if ctx.review.targetBranch != merge.target.name { reasons.append(.badTarget) }
      if ctx.review.author.username != ctx.gitlab.botLogin { reasons.append(.configuration) }
      excludes = [.make(remote: merge.target), .make(sha: merge.fork)]
    }
    let head = try Git.Sha(value: ctx.review.pipeline.sha)
    for branch in try listTrackingBranches(cfg: cfg) {
      guard fusion.targets.isMet(branch.name) else { continue }
      let base = try Execute.parseText(reply: execute(cfg.git.mergeBase(
        .make(remote: branch),
        .make(sha: head)
      )))
      let extras = try Execute.parseLines(reply: execute(cfg.git.listCommits(
        in: [.make(sha: .init(value: base))],
        notIn: excludes,
        noMerges: false,
        firstParents: false
      )))
      guard !extras.isEmpty else { continue }
      reasons.append(.forkPoint)
      break
    }
    guard reasons.isEmpty else {
      try report(cfg.reportReviewBlocked(
        review: ctx.review,
        users: worker.resolveParticipants(
          cfg: cfg,
          gitlabCi: ctx.gitlab,
          source: .make(sha: .init(value: ctx.job.pipeline.sha)),
          target: .make(remote: .init(name: ctx.review.targetBranch))
        ),
        reasons: reasons
      ))
      return false
    }
    return true
  }
  func checkIsRebased(
    cfg: Configuration,
    ctx: Worker.ParentReview
  ) throws -> Bool {
    let parents = try Id(ctx.review.pipeline.sha)
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .map(cfg.git.listParents(ref:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .map(Git.Sha.init(value:))
    guard parents.count == 2 else { return false }
    let target = try Id(ctx.review.targetBranch)
      .map(Git.Branch.init(name:))
      .map(Git.Ref.make(remote:))
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .get()
    guard target == parents[1] else { return false }
    return true
  }
  func listTrackingBranches(cfg: Configuration) throws -> [Git.Branch] {
    var result: [Git.Branch] = []
    for line in try Execute.parseLines(reply: execute(cfg.git.listAllRefs)) {
      let pair = line.components(separatedBy: .whitespaces)
      guard pair.count == 2 else { throw MayDay("bad git reply") }
      guard let name = try? pair[1].dropPrefix("refs/remotes/origin/") else { continue }
      try result.append(.init(name: name))
    }
    return result
  }
  func rebaseReview(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    fusion: Fusion
  ) throws -> Git.Sha? {
    let initial = try Id(.head)
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let sha = try Git.Ref.make(sha: .init(value: ctx.review.pipeline.sha))
    let message = try generate(cfg.createFusionMergeCommitMessage(
      fusion: fusion,
      review: ctx.review
    ))
    let name = try Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: sha)))
    let email = try Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: sha)))
    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: sha)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    do {
      try Execute.checkStatus(reply: execute(cfg.git.merge(
        ref: .make(remote: .init(name: ctx.review.targetBranch)),
        message: message,
        noFf: true,
        env: Git.env(
          authorName: name,
          authorEmail: email,
          commiterName: name,
          commiterEmail: email
        ),
        escalate: true
      )))
    } catch {
      try Execute.checkStatus(reply: execute(cfg.git.quitMerge))
      try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: initial)))
      try Execute.checkStatus(reply: execute(cfg.git.clean))
      return nil
    }
    let result = try Id(.head)
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .get()
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: initial)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    return result
  }
  func closeReview(cfg: Configuration, ctx: Worker.ParentReview) throws {
    try ctx.gitlab
      .putMrState(parameters: .init(stateEvent: "close"), review: ctx.review.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try Id
      .make(cfg.git.push(
        url: ctx.gitlab.pushUrl.get(),
        delete: .init(name: ctx.review.sourceBranch)
      ))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  func acceptReview(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    message: String
  ) throws -> Bool {
    let result = try ctx.gitlab
      .putMrMerge(
        parameters: .init(
          mergeCommitMessage: message,
          squashCommitMessage: message,
          squash: ctx.review.squash,
          shouldRemoveSourceBranch: true,
          sha: .init(value: ctx.review.pipeline.sha)
        ),
        review: ctx.review.iid
      )
      .map(execute)
      .map(\.data)
      .get()
      .reduce(AnyCodable.self, jsonDecoder.decode(_:from:))
    if case "merged"? = result?.map?["state"]?.value?.string {
      logMessage(.init(message: "Review merged"))
      try report(cfg.reportReviewMerged(
        review: ctx.review,
        users: worker.resolveParticipants(
          cfg: cfg,
          gitlabCi: ctx.gitlab,
          source: .make(sha: .init(value: ctx.job.pipeline.sha)),
          target: .make(remote: .init(name: ctx.review.targetBranch))
        )
      ))
      return true
    } else if let message = result?.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      try report(cfg.reportReviewMergeError(
        review: ctx.review,
        users: worker.resolveParticipants(
          cfg: cfg,
          gitlabCi: ctx.gitlab,
          source: .make(sha: .init(value: ctx.job.pipeline.sha)),
          target: .make(remote: .init(name: ctx.review.targetBranch))
        ),
        error: message
      ))
      return false
    } else {
      throw MayDay("Unexpected merge response")
    }
  }
  func shiftReplication(
    cfg: Configuration,
    merge: Fusion.Merge
  ) throws -> Fusion.Merge? { try Id
    .make(cfg.git.listCommits(
      in: [.make(remote: merge.source)],
      notIn: [.make(sha: merge.fork)],
      noMerges: false,
      firstParents: true
    ))
    .map(execute)
    .map(Execute.parseLines(reply:))
    .get()
    .last
    .map(merge.changing(fork:))
  }
  func createReview(
    cfg: Configuration,
    gitlab: GitlabCi,
    merge: Fusion.Merge,
    title: String
  ) throws {
    try Id
      .make(cfg.git.push(
        url: gitlab.pushUrl.get(),
        branch: merge.supply,
        sha: merge.fork,
        force: false
      ))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try gitlab
      .postMergeRequests(parameters: .init(
        sourceBranch: merge.supply.name,
        targetBranch: merge.target.name,
        title: title
      ))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
}
