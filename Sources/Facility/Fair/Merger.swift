import Foundation
import Facility
import FacilityPure
public final class Merger {
  let execute: Try.Reply<Execute>
  let resolveFusion: Try.Reply<Configuration.ResolveFusion>
  let resolveFusionStatuses: Try.Reply<Configuration.ResolveFusionStatuses>
  let resolveReviewQueue: Try.Reply<Fusion.Queue.Resolve>
  let resolveApprovers: Try.Reply<Configuration.ResolveApprovers>
  let parseApprovalRules: Try.Reply<Configuration.ParseYamlFile<Yaml.Fusion.Approval.Rules>>
  let parseCodeOwnage: Try.Reply<Configuration.ParseYamlFile<[String: Yaml.Criteria]>>
  let parseProfile: Try.Reply<Configuration.ParseYamlFile<Yaml.Profile>>
  let parseAntagonists: Try.Reply<Configuration.ParseYamlSecret<[String: Set<String>]>>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  let writeStdout: Act.Of<String>.Go
  let generate: Try.Reply<Generate>
  let report: Act.Reply<Report>
  let createThread: Try.Reply<Report.CreateThread>
  let logMessage: Act.Reply<LogMessage>
  let worker: Worker
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveFusion: @escaping Try.Reply<Configuration.ResolveFusion>,
    resolveFusionStatuses: @escaping Try.Reply<Configuration.ResolveFusionStatuses>,
    resolveReviewQueue: @escaping Try.Reply<Fusion.Queue.Resolve>,
    resolveApprovers: @escaping Try.Reply<Configuration.ResolveApprovers>,
    parseApprovalRules: @escaping Try.Reply<Configuration.ParseYamlFile<Yaml.Fusion.Approval.Rules>>,
    parseCodeOwnage: @escaping Try.Reply<Configuration.ParseYamlFile<[String: Yaml.Criteria]>>,
    parseProfile: @escaping Try.Reply<Configuration.ParseYamlFile<Yaml.Profile>>,
    parseAntagonists: @escaping Try.Reply<Configuration.ParseYamlSecret<[String: Set<String>]>>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
    writeStdout: @escaping Act.Of<String>.Go,
    generate: @escaping Try.Reply<Generate>,
    report: @escaping Act.Reply<Report>,
    createThread: @escaping Try.Reply<Report.CreateThread>,
    logMessage: @escaping Act.Reply<LogMessage>,
    worker: Worker,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.resolveFusion = resolveFusion
    self.resolveFusionStatuses = resolveFusionStatuses
    self.resolveReviewQueue = resolveReviewQueue
    self.resolveApprovers = resolveApprovers
    self.parseApprovalRules = parseApprovalRules
    self.parseCodeOwnage = parseCodeOwnage
    self.parseProfile = parseProfile
    self.parseAntagonists = parseAntagonists
    self.persistAsset = persistAsset
    self.writeStdout = writeStdout
    self.generate = generate
    self.report = report
    self.createThread = createThread
    self.logMessage = logMessage
    self.worker = worker
    self.jsonDecoder = jsonDecoder
  }
  public func startProposition(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    let kind = try fusion.makeKind(supply: ctx.review.sourceBranch)
    guard case .proposition = kind else { throw Thrown("Wrong review kind") }
    let approvers = try resolveApprovers(.init(cfg: cfg, approval: fusion.approval))
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    guard statuses[ctx.review.iid] == nil else { return true }
    let authors = try worker.resolveAuthors(cfg: cfg, ctx: ctx, kind: kind)
    let thread = try createThread(cfg.reportReviewCreated(
      fusion: fusion,
      review: ctx.review,
      users: approvers,
      authors: authors
    ))
    statuses[ctx.review.iid] = Fusion.Approval.Status.make(
      target: ctx.review.targetBranch,
      authors: authors,
      thread: .make(yaml: thread),
      fork: nil
    )
    return try persistAsset(.init(
      cfg: cfg,
      asset: fusion.approval.statuses,
      content: Fusion.Approval.Status.yaml(statuses: statuses),
      message: generate(cfg.createFusionStatusesCommitMessage(
        asset: fusion.approval.statuses,
        review: ctx.review
      ))
    ))
  }
  public func updateReview(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    var review = try resolveReview(cfg: cfg, ctx: ctx, fusion: fusion, statuses: statuses)
    guard try checkIsRebased(cfg: cfg, ctx: ctx) else {
      if let sha = try rebaseReview(cfg: cfg, ctx: ctx, fusion: fusion) {
        try Execute.checkStatus(reply: execute(cfg.git.push(
          url: ctx.gitlab.protected.get().push,
          branch: .init(name: ctx.review.sourceBranch),
          sha: sha,
          force: false
        )))
      } else {
        report(cfg.reportReviewMergeConflicts(review: review, state: ctx.review))
        try changeQueue(cfg: cfg, ctx: ctx, fusion: fusion, enqueue: false)
      }
      return false
    }
    if let reason = try checkReviewClosers(cfg: cfg, ctx: ctx, kind: review.kind) {
      try closeReview(cfg: cfg, ctx: ctx)
      report(cfg.reportReviewClosed(review: review, state: ctx.review, reason: reason))
      try changeQueue(cfg: cfg, ctx: ctx, fusion: fusion, enqueue: false)
      return false
    }
    if let blockers = try checkReviewBlockers(cfg: cfg, ctx: ctx, review: review) {
      report(cfg.reportReviewBlocked(review: review, state: ctx.review, reasons: blockers))
      try changeQueue(cfg: cfg, ctx: ctx, fusion: fusion, enqueue: false)
      return false
    }
    let approval = try updateApproval(cfg: cfg, ctx: ctx, fusion: fusion, review: &review)
    if let troubles = approval.troubles {
      report(cfg.reportReviewTroubles(review: review, state: ctx.review, troubles: troubles))
    }
    guard approval.update.state.isApproved else {
      try changeQueue(cfg: cfg, ctx: ctx, fusion: fusion, enqueue: false)
      return false
    }
//    guard try checkIsSquashed(cfg: cfg, ctx: ctx, kind: kind) else {
//      let sha = try squashReview(cfg: cfg, ctx: ctx, fusion: fusion, kind: kind)
//      try pushReview(cfg: cfg, ctx: ctx, sha: sha)
//      try squashApproves(cfg: cfg, ctx: ctx, fusion: fusion, sha: sha)
//
//      return false
//    }
    #warning("tbd")
    return true
  }
  public func acceptReview(cfg: Configuration) throws -> Bool {
//    let fusion = try resolveFusion(.init(cfg: cfg))
//    let ctx = try worker.resolveParentReview(cfg: cfg)
//    guard worker.isLastPipe(ctx: ctx) else { return false }
//    let kind = try fusion.makeKind(supply: ctx.review.sourceBranch)
//    guard try checkIsRebased(cfg: cfg, ctx: ctx) else { return false }
//    guard try checkFusionErrors(cfg: cfg, fusion: fusion, kind: kind) == nil else { return false }
//    guard try checkReviewErrors(cfg: cfg, ctx: ctx, fusion: fusion, kind: kind) else { return false }
//    guard try checkIsApproved() else { return false }
//    guard try checkIsSquashed(cfg: cfg, ctx: ctx, kind: kind) else { return false }
//    switch kind {
//    case .proposition:
//      guard try acceptReview(cfg: cfg, ctx: ctx, message: generate(cfg.createPropositionCommitMessage(
//        proposition: fusion.proposition,
//        review: ctx.review
//      ))) else { return false }
//    case .replication(let merge):
//      guard try acceptReview(cfg: cfg, ctx: ctx, message: generate(cfg.createReplicationCommitMessage(
//        replication: fusion.replication,
//        merge: merge
//      ))) else { return false }
//      if let merge = try shiftReplication(cfg: cfg, merge: merge) {
//        try createReview(
//          cfg: cfg,
//          gitlab: ctx.gitlab,
//          merge: merge,
//          title: generate(cfg.createReplicationCommitMessage(
//            replication: fusion.replication,
//            merge: merge
//          ))
//        )
//      }
//    case .integration(let merge):
//      guard try acceptReview(cfg: cfg, ctx: ctx, message: generate(cfg.createIntegrationCommitMessage(
//        integration: fusion.integration,
//        merge: merge
//      ))) else { return false }
//    }
    #warning("tbd")
    return true
  }
  public func startReplication(cfg: Configuration) throws -> Bool {
//    let gitlabCi = try cfg.gitlabCi.get()
//    let parent = try gitlabCi.parent.get()
//    let job = try gitlabCi.getJob(id: parent.job)
//      .map(execute)
//      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
//      .get()
//    let fusion = try resolveFusion(.init(cfg: cfg))
//    let merge = try fusion.replication.makeMerge(source: job.pipeline.ref, fork: job.pipeline.sha)
//    if let error = try checkFusionErrors(cfg: cfg, fusion: fusion, kind: .integration(merge)) {
//      logMessage(.init(message: error))
//      return false
//    }
//    try createReview(
//      cfg: cfg,
//      gitlab: cfg.gitlabCi.get(),
//      merge: merge,
//      title: generate(cfg.createReplicationCommitMessage(
//        replication: fusion.replication,
//        merge: merge
//      ))
//    )
    #warning("tbd")
    return true
  }
  public func startIntegration(
    cfg: Configuration,
    source: String,
    target: String,
    fork: String
  ) throws -> Bool {
//    let fusion = try resolveFusion(.init(cfg: cfg))
//    let merge = try fusion.integration.makeMerge(target: target, source: source, fork: fork)
//    if let error = try checkFusionErrors(cfg: cfg, fusion: fusion, kind: .integration(merge)) {
//      logMessage(.init(message: error))
//      return false
//    }
//    try createReview(
//      cfg: cfg,
//      gitlab: cfg.gitlabCi.get(),
//      merge: merge,
//      title: generate(cfg.createIntegrationCommitMessage(
//        integration: fusion.integration,
//        merge: merge
//      ))
//    )
    #warning("tbd")
    return true
  }
  public func renderIntegration(cfg: Configuration) throws -> Bool {
//    let gitlabCi = try cfg.gitlabCi.get()
//    let parent = try gitlabCi.parent.get()
//    let job = try gitlabCi.getJob(id: parent.job)
//      .map(execute)
//      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
//      .get()
//    let fusion = try resolveFusion(.init(cfg: cfg))
//    let fork = try Git.Sha(value: job.pipeline.sha)
//    let source = try Git.Branch(name: job.pipeline.ref)
//    let rules = try fusion.integration.rules
//      .filter { $0.source.isMet(source.name) }
//      .mapEmpty { throw Thrown("Integration for \(source.name) not configured") }
//    var targets: [String] = []
//    for target in try listTrackingBranches(cfg: cfg) {
//      guard fusion.targets.isMet(target.name) else { continue }
//      guard rules.contains(where: { $0.target.isMet(target.name) }) else { continue }
//      guard try !Execute.parseSuccess(reply: execute(cfg.git.check(
//        child: .make(remote: target),
//        parent: .make(sha: fork)
//      ))) else { continue }
//      targets.append(target.name)
//    }
//    guard !targets.isEmpty else { throw Thrown("No branches suitable for integration") }
//    try writeStdout(generate(cfg.exportIntegrationTargets(
//      integration: fusion.integration,
//      fork: fork,
//      source: source.name,
//      targets: targets
//    )))
    #warning("tbd")
    return true
  }
  func resolveReview(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    fusion: Fusion,
    statuses: [UInt: Fusion.Approval.Status]
  ) throws -> Review { try .make(
    gitlabCi: ctx.gitlab,
    statuses: statuses,
    approvers: resolveApprovers(.init(cfg: cfg, approval: fusion.approval)),
    review: ctx.review,
    kind: fusion.makeKind(supply: ctx.review.sourceBranch),
    ownage: ctx.gitlab.env.parent
      .map(\.profile)
      .reduce(.make(sha: .init(value: ctx.review.pipeline.sha)), Git.File.init(ref:path:))
      .map { file in try Configuration.Profile.make(
        profile: file,
        yaml: parseProfile(.init(git: cfg.git, file: file))
      )}
      .map(\.codeOwnage)
      .get()
      .reduce(cfg.git, Configuration.ParseYamlFile<[String: Yaml.Criteria]>.init(git:file:))
      .map(parseCodeOwnage)
      .get([:])
      .mapValues(Criteria.init(yaml:)),
    rules: .make(yaml: parseApprovalRules(.init(
      git: cfg.git,
      file: fusion.approval.rules
    ))),
    haters: fusion.approval.haters
      .reduce(cfg, Configuration.ParseYamlSecret.init(cfg:secret:))
      .map(parseAntagonists)
      .get([:])
  )}
  func updateApproval(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    fusion: Fusion,
    review: inout Review
  ) throws -> Review.Approval {
    let fork = review.kind.merge
      .map(\.fork)
      .map(Git.Ref.make(sha:))
    let current = try Git.Ref.make(sha: .init(value: ctx.review.pipeline.sha))
    let target = try Git.Ref.make(remote: .init(name: ctx.review.targetBranch))
    try review.addDiff(files: listAllChanges(cfg: cfg, ctx: ctx, kind: review.kind))
    try review.status.approves.values
      .filter(\.resolution.approved)
      .reduce(into: Set(), { $0.insert($1.commit) })
      .forEach { sha in try review.addBreakers(
        sha: sha,
        commits: try? Execute.parseLines(reply: execute(cfg.git.listCommits(
          in: [current],
          notIn: [target, .make(sha: sha)] + fork.array,
          noMerges: false,
          firstParents: false
        )))
      )}
    for sha in try Execute.parseLines(reply: execute(cfg.git.listCommits(
      in: [current],
      notIn: [target] + fork.array,
      noMerges: false,
      firstParents: false
    ))) {
      let sha = try Git.Sha(value: sha)
      try review.addChanges(sha: sha, files: listChangedFiles(cfg: cfg, ctx: ctx, sha: sha))
    }
    return review.updateApproval()
  }
  func checkReviewClosers(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    kind: Fusion.Kind
  ) throws -> Report.ReviewClosed.Reason? {
    switch kind {
    case .proposition(let rule):
      guard rule != nil else { return .noSourceRule }
    case .replication(let merge):
      guard try ctx.review.author.username == ctx.gitlab.protected.get().user.username
      else { return .authorNotBot }
      guard try !Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork)
      ))) else { return .forkInTarget }
      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork).make(parent: 1)
      ))) else { return .forkParentNotInTarget }
      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.source),
        parent: .make(sha: merge.fork)
      ))) else { return .forkNotInSource }
      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.supply),
        parent: .make(sha: merge.fork)
      ))) else { return .forkNotInSupply }
      let target = try worker.resolveBranch(cfg: cfg, name: merge.target.name)
      guard target.protected else { return .targetNotProtected }
      guard target.default else { return .targetNotDefault }
      let source = try worker.resolveBranch(cfg: cfg, name: merge.source.name)
      guard source.protected else { return .sourceNotProtected }
    case .integration(let merge):
      guard try ctx.review.author.username == ctx.gitlab.protected.get().user.username
      else { return .authorNotBot }
      guard try !Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.target),
        parent: .make(sha: merge.fork)
      ))) else { return .forkInTarget }
      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.source),
        parent: .make(sha: merge.fork)
      ))) else { return .forkNotInSource }
      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.supply),
        parent: .make(sha: merge.fork)
      ))) else { return .forkNotInSupply }
      let target = try worker.resolveBranch(cfg: cfg, name: merge.target.name)
      guard target.protected else { return .targetNotProtected }
      let source = try worker.resolveBranch(cfg: cfg, name: merge.source.name)
      guard source.protected else { return .sourceNotProtected }
    }
    return nil
  }
  func checkReviewBlockers(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    review: Review
  ) throws -> [Report.ReviewBlocked.Reason]? {
    var result: [Report.ReviewBlocked.Reason] = []
    if ctx.review.draft { result.append(.draft) }
    if ctx.review.workInProgress { result.append(.workInProgress) }
    if !ctx.review.blockingDiscussionsResolved { result.append(.blockingDiscussions) }
    if
      let sanity = review.rules.sanity,
      !cfg.profile.checkSanity(criteria: review.ownage[sanity])
    { result.append(.sanity) }
    let excludes: [Git.Ref]
    switch review.kind {
    case .proposition(let rule):
      if !ctx.review.squash { result.append(.squashStatus) }
      let target = try worker.resolveBranch(cfg: cfg, name: ctx.review.targetBranch)
      if !target.protected { result.append(.badTarget) }
      guard let rule = rule else { throw MayDay("no proposition rule") }
      if !rule.title.isMet(ctx.review.title) { result.append(.badTitle) }
      if let task = rule.task {
        let source = try findMatches(in: ctx.review.sourceBranch, regexp: task)
        let title = try findMatches(in: ctx.review.title, regexp: task)
        if source.symmetricDifference(title).isEmpty { result.append(.taskMismatch) }
      }
      try excludes = [.make(remote: .init(name: ctx.review.targetBranch))]
    case .replication(let merge), .integration(let merge):
      if ctx.review.squash { result.append(.squashStatus) }
      if ctx.review.targetBranch != merge.target.name { result.append(.badTarget) }
      excludes = [.make(remote: merge.target), .make(sha: merge.fork)]
    }
    let head = try Git.Sha(value: ctx.job.pipeline.sha)
    for branch in try worker.resolveProtectedBranches(cfg: cfg) {
      guard let base = try? Execute.parseText(reply: execute(cfg.git.mergeBase(
        .make(remote: branch),
        .make(sha: head)
      ))) else { continue }
      let extras = try Execute.parseLines(reply: execute(cfg.git.listCommits(
        in: [.make(sha: .init(value: base))],
        notIn: excludes,
        noMerges: false,
        firstParents: false
      )))
      guard !extras.isEmpty else { continue }
      result.append(.extraCommits)
      break
    }
    return result.isEmpty.else(result)
  }
  func checkIsRebased(
    cfg: Configuration,
    ctx: Worker.ParentReview
  ) throws -> Bool {
    try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(sha: .init(value: ctx.review.pipeline.sha)),
      parent: .make(remote: .init(name: ctx.review.targetBranch))
    )))
  }
  func checkIsSquashed(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    kind: Fusion.Kind
  ) throws -> Bool {
    guard let sha = kind.merge?.fork else { return true }
    let parents = try Id(ctx.review.pipeline.sha)
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .map(cfg.git.listParents(ref:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .map(Git.Sha.init(value:))
    let target = try Id(ctx.review.targetBranch)
      .map(Git.Branch.init(name:))
      .map(Git.Ref.make(remote:))
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .get()
    return parents == [sha, target]
  }
  func listAllChanges(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    kind: Fusion.Kind
  ) throws -> [String] {
    let target = try Git.Ref.make(remote: .init(name: ctx.review.targetBranch))
    let current = try Git.Ref.make(sha: .init(value: ctx.job.pipeline.sha))
    if let fork = kind.merge?.fork {
      return try listMergeChanges(cfg: cfg, ref: current, parents: [target, .make(sha: fork)])
    } else {
      return try Execute.parseLines(reply: execute(cfg.git.listChangedFiles(
        source: current,
        target: target
      )))
    }
  }
  func listChangedFiles(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    sha: Git.Sha
  ) throws -> [String] {
    let sha = Git.Ref.make(sha: sha)
    let parents = try Execute.parseLines(reply: execute(cfg.git.listParents(ref: sha)))
    if parents.count > 1 {
      return try listMergeChanges(
        cfg: cfg,
        ref: sha,
        parents: parents
          .map(Git.Sha.init(value:))
          .map(Git.Ref.make(sha:))
      )
    } else {
      return try Execute.parseLines(reply: execute(cfg.git.listChangedFiles(
        source: sha,
        target: sha.make(parent: 1)
      )))
    }
  }
  func listMergeChanges(
    cfg: Configuration,
    ref: Git.Ref,
    parents: [Git.Ref]
  ) throws -> [String] {
    guard parents.count > 1 else { throw MayDay("not a merge") }
    let initial = try Execute.parseText(reply: execute(cfg.git.getSha(ref: .head)))
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: parents[0])))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    try Execute.checkStatus(reply: execute(cfg.git.merge(
      refs: .init(parents[1..<parents.endIndex]),
      message: nil,
      noFf: true,
      escalate: false
    )))
    try Execute.checkStatus(reply: execute(cfg.git.quitMerge))
    try Execute.checkStatus(reply: execute(cfg.git.addAll))
    try Execute.checkStatus(reply: execute(cfg.git.resetSoft(ref: ref)))
    let result = try Execute.parseLines(reply: execute(cfg.git.listLocalChanges))
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(
      ref: .make(sha: .init(value: initial))
    )))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    return result
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
  @discardableResult
  func changeQueue(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    fusion: Fusion,
    enqueue: Bool
  ) throws -> Bool {
    var queue = try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
    let notifiables = queue.enqueue(
      review: ctx.review.iid,
      target: enqueue.then(ctx.review.targetBranch)
    )
    let message = try generate(cfg.createReviewQueueCommitMessage(
      asset: fusion.queue,
      review: ctx.review,
      queued: enqueue
    ))
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: fusion.queue,
      content: queue.yaml,
      message: message
    ))
    for notifiable in notifiables {
      try Execute.checkStatus(reply: execute(ctx.gitlab.postMrPipelines(review: notifiable).get()))
    }
    return queue.isFirst(review: ctx.review.iid, target: ctx.review.targetBranch)
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
        refs: [.make(remote: .init(name: ctx.review.targetBranch))],
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
  func squashReview(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    fusion: Fusion,
    kind: Fusion.Kind
  ) throws -> Git.Sha {
    guard let merge = kind.merge else { throw MayDay("Squashing proposition") }
    let fork = Git.Ref.make(sha: merge.fork)
    let name = try Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: fork)))
    let email = try Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: fork)))
    return try Git.Sha(value: Execute.parseText(reply: execute(cfg.git.commitTree(
      tree: .init(ref: .make(sha: .init(value: ctx.job.pipeline.sha))),
      message: generate(cfg.createFusionMergeCommitMessage(
        fusion: fusion,
        review: ctx.review
      )),
      parents: [fork, .make(remote: merge.target)],
      env: Git.env(
        authorName: name,
        authorEmail: email,
        commiterName: name,
        commiterEmail: email
      )
    ))))
  }
  func squashApproves(
    cfg: Configuration,
    ctx: Worker.ParentReview,
    fusion: Fusion,
    sha: Git.Sha
  ) throws {
    #warning("tbd")
  }
  func closeReview(cfg: Configuration, ctx: Worker.ParentReview) throws {
    try ctx.gitlab
      .putMrState(parameters: .init(stateEvent: "close"), review: ctx.review.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try Id
      .make(cfg.git.push(
        url: ctx.gitlab.protected.get().push,
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
    #warning("tbd")
    return false
//    let result = try ctx.gitlab
//      .putMrMerge(
//        parameters: .init(
//          mergeCommitMessage: message,
//          squashCommitMessage: message,
//          squash: ctx.review.squash,
//          shouldRemoveSourceBranch: true,
//          sha: .init(value: ctx.review.pipeline.sha)
//        ),
//        review: ctx.review.iid
//      )
//      .map(execute)
//      .map(\.data)
//      .get()
//      .reduce(AnyCodable.self, jsonDecoder.decode(_:from:))
//    if case "merged"? = result?.map?["state"]?.value?.string {
//      logMessage(.init(message: "Review merged"))
//      try report(cfg.reportReviewMerged(
//        review: ctx.review,
//        users: worker.resolveParticipants(
//          cfg: cfg,
//          gitlabCi: ctx.gitlab,
//          source: .make(sha: .init(value: ctx.job.pipeline.sha)),
//          target: .make(remote: .init(name: ctx.review.targetBranch))
//        )
//      ))
//      return true
//    } else if let message = result?.map?["message"]?.value?.string {
//      logMessage(.init(message: message))
//      try report(cfg.reportReviewMergeError(
//        review: ctx.review,
//        users: worker.resolveParticipants(
//          cfg: cfg,
//          gitlabCi: ctx.gitlab,
//          source: .make(sha: .init(value: ctx.job.pipeline.sha)),
//          target: .make(remote: .init(name: ctx.review.targetBranch))
//        ),
//        error: message
//      ))
//      return false
//    } else {
//      throw MayDay("Unexpected merge response")
//    }
  }
  func shiftReplication(
    cfg: Configuration,
    merge: Fusion.Merge
  ) throws -> Fusion.Merge? {
    let fork = try Id
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
      .map(Git.Sha.init(value:))
    guard let fork = fork else { return nil }
    return try .make(fork: fork, source: merge.source, target: merge.target, isReplication: true)
  }
  func createReview(
    cfg: Configuration,
    gitlab: GitlabCi,
    merge: Fusion.Merge,
    title: String
  ) throws {
    guard try !Execute.parseSuccess(reply: execute(cfg.git.checkObjectType(
      ref: .make(remote: merge.supply)
    ))) else {
      logMessage(.init(message: "Fusion already in progress"))
      return
    }
    try Id
      .make(cfg.git.push(
        url: gitlab.protected.get().push,
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
  func findMatches(in string: String, regexp: NSRegularExpression) throws -> Set<String> {
    var result: Set<String> = []
    for match in regexp.matches(
      in: string,
      options: .withoutAnchoringBounds,
      range: .init(string.startIndex..<string.endIndex, in: string)
    ) {
      guard match.range.location != NSNotFound, let range = Range(match.range, in: string)
      else { continue }
      result.insert(String(string[range]))
    }
    return result
  }
}
