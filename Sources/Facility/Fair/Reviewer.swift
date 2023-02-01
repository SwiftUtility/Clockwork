import Foundation
import Facility
import FacilityPure
public final class Reviewer {
  let execute: Try.Reply<Execute>
  let parseReview: Try.Reply<ParseYamlFile<Review>>
  let parseReviewStorage: Try.Reply<ParseYamlFile<Review.Storage>>
  let parseReviewRules: Try.Reply<ParseYamlSecret<Review.Rules>>
  let parseCodeOwnage: Try.Reply<ParseYamlFile<[String: Criteria]>>
  let parseProfile: Try.Reply<ParseYamlFile<Configuration.Profile>>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  let writeStdout: Act.Of<String>.Go
  let generate: Try.Reply<Generate>
  let report: Act.Reply<Report>
  let readStdin: Try.Reply<Configuration.ReadStdin>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    parseReview: @escaping Try.Reply<ParseYamlFile<Review>>,
    parseReviewStorage: @escaping Try.Reply<ParseYamlFile<Review.Storage>>,
    parseReviewRules: @escaping Try.Reply<ParseYamlSecret<Review.Rules>>,
    parseCodeOwnage: @escaping Try.Reply<ParseYamlFile<[String: Criteria]>>,
    parseProfile: @escaping Try.Reply<ParseYamlFile<Configuration.Profile>>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
    writeStdout: @escaping Act.Of<String>.Go,
    generate: @escaping Try.Reply<Generate>,
    report: @escaping Act.Reply<Report>,
    readStdin: @escaping Try.Reply<Configuration.ReadStdin>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.parseReview = parseReview
    self.parseReviewStorage = parseReviewStorage
    self.parseReviewRules = parseReviewRules
    self.parseCodeOwnage = parseCodeOwnage
    self.parseProfile = parseProfile
    self.persistAsset = persistAsset
    self.writeStdout = writeStdout
    self.generate = generate
    self.report = report
    self.readStdin = readStdin
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func signal(
    cfg: Configuration,
    event: String,
    stdin: Configuration.ReadStdin,
    args: [String]
  ) throws -> Bool {
//    let stdin = try readStdin(stdin)
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    guard let status = try resolveStatus(cfg: cfg, fusion: fusion, statuses: &statuses)
//    else { return false }
//    report(cfg.reportReviewCustom(
//      status: status,
//      event: event,
//      stdin: stdin
//    ))
//    return true
    #warning("tbd")
    return false
  }
  public func updateReviews(cfg: Configuration, remind: Bool) throws -> Bool {
    #warning("tbd sync obsolete integrations")
    #warning("tbd recheck stuck reviews")
    #warning("tbd sync obsolete in queue")
    #warning("tbd recheck blocked replications")

//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    let gitlab = try cfg.gitlab.get()
//    for status in statuses.values {
//      let state = try gitlab.getMrState(review: status.review)
//        .map(execute)
//        .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
//        .get()
//      guard state.state != "closed" else {
//        report(cfg.reportReviewClosed(
//          status: status,
//          review: state
//        ))
//        statuses[state.iid] = nil
//        continue
//      }
//      guard remind else { continue }
//      guard let review = try resolveReview(
//        cfg: cfg,
//        fusion: fusion,
//        status: status,
//        review: state
//      ) else { continue }
//      let reminds = review.status.reminds(sha: state.lastPipeline.sha, approvers: gitlab.users)
//      guard reminds.isEmpty.not else { continue }
//      report(cfg.reportReviewRemind(status: status, slackers: reminds, review: state))
//    }
//    _ = try persistAsset(.init(
//      cfg: cfg,
//      asset: fusion.approval.statuses,
//      content: Fusion.Approval.Status.serialize(statuses: statuses),
//      message: generate(cfg.createFusionStatusesCommitMessage(fusion: fusion, reason: .clean))
//    ))
//    return true
    #warning("tbd")
    return false
  }
  public func patchReview(
    cfg: Configuration,
    skip: Bool,
    path: String,
    message: String
  ) throws -> Bool {
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let gitlab = try cfg.gitlab.get()
//    let parent = try gitlab.parent.get()
//    let merge = try gitlab.review.get()
//    guard parent.pipeline.id == merge.lastPipeline.id else {
//      logMessage(.pipelineOutdated)
//      return false
//    }
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    guard var status = statuses[merge.iid] else { return false }
//    guard try !parseReviewQueue(cfg.parseReviewQueue(fusion: fusion)).isFirst(review: merge) else {
//      logMessage(.init(message: "Review is validating"))
//      return false
//    }
//    let patch = try cfg.gitlab
//      .flatMap({ $0.loadArtifact(job: parent.id, file: path) })
//      .map(execute)
//      .map(Execute.parseData(reply:))
//      .get()
//    let initial = try Id(.head)
//      .map(cfg.git.getSha(ref:))
//      .map(execute)
//      .map(Execute.parseText(reply:))
//      .map(Git.Sha.make(value:))
//      .map(Git.Ref.make(sha:))
//      .get()
//    let result: Git.Sha?
//    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: .make(sha: .make(job: parent)))))
//    try Execute.checkStatus(reply: execute(cfg.git.clean))
//    try Execute.checkStatus(reply: execute(cfg.git.apply(patch: patch)))
//    if try Execute.parseLines(reply: execute(cfg.git.changesList)).isEmpty.not {
//      try Execute.checkStatus(reply: execute(cfg.git.addAll))
//      try Execute.checkStatus(reply: execute(cfg.git.commit(message: message)))
//      result = try .make(value: Execute.parseText(reply: execute(cfg.git.getSha(ref: .head))))
//    } else {
//      result = nil
//    }
//    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: initial)))
//    try Execute.checkStatus(reply: execute(cfg.git.clean))
//    guard let result = result else { return false }
//    if skip {
//      status.skip.insert(result)
//      statuses[status.review] = status
//      _ = try persistAsset(.init(
//        cfg: cfg,
//        asset: fusion.approval.statuses,
//        content: Fusion.Approval.Status.serialize(statuses: statuses),
//        message: generate(cfg.createFusionStatusesCommitMessage(fusion: fusion, reason: .skipCommit))
//      ))
//    }
//    try Execute.checkStatus(reply: execute(cfg.git.push(
//      url: cfg.gitlab.flatMap(\.rest).get().push,
//      branch: .make(name: merge.sourceBranch),
//      sha: result,
//      force: false,
//      secret: cfg.gitlab.flatMap(\.rest).get().secret
//    )))
//    return true
    #warning("tbd")
    return false
  }
  public func skipReview(
    cfg: Configuration,
    iid: UInt
  ) throws -> Bool {
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let gitlab = try cfg.gitlab.get()
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    let state = try gitlab.getMrState(review: iid)
//      .map(execute)
//      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
//      .get()
//    guard var status = statuses[iid] else { return false }
//    status.emergent = try .make(value: state.lastPipeline.sha)
//    statuses[status.review] = status
//    return try persistAsset(.init(
//      cfg: cfg,
//      asset: fusion.approval.statuses,
//      content: Fusion.Approval.Status.serialize(statuses: statuses),
//      message: generate(cfg.createFusionStatusesCommitMessage(fusion: fusion, reason: .cheat))
//    ))
    #warning("tbd")
    return false
  }
  public func approveReview(
    cfg: Configuration,
    advance: Bool
  ) throws -> Bool {
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let gitlab = try cfg.gitlab.get()
//    let parent = try gitlab.parent.get()
//    let merge = try gitlab.review.get()
//    guard parent.pipeline.id == merge.lastPipeline.id else {
//      logMessage(.pipelineOutdated)
//      return false
//    }
//    guard try !parseReviewQueue(cfg.parseReviewQueue(fusion: fusion)).isFirst(review: merge) else {
//      logMessage(.init(message: "Review is validating"))
//      return false
//    }
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    guard var status = statuses[merge.iid] else {
//      logMessage(.init(message: "No review status \(merge.iid)"))
//      return false
//    }
//    try status.approve(job: parent, approvers: gitlab.users, resolution: resolution)
//    statuses[status.review] = status
//    return try persistAsset(.init(
//      cfg: cfg,
//      asset: fusion.approval.statuses,
//      content: Fusion.Approval.Status.serialize(statuses: statuses),
//      message: generate(cfg.createFusionStatusesCommitMessage(fusion: fusion, reason: .approve))
//    ))
    #warning("tbd")
    return false
  }
  public func dequeueReview(cfg: Configuration) throws -> Bool {
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let gitlab = try cfg.gitlab.get()
//    let parent = try gitlab.parent.get()
//    let merge = try gitlab.review.get()
//    guard parent.pipeline.id == merge.lastPipeline.id else {
//      logMessage(.pipelineOutdated)
//      return false
//    }
//    var queue = try parseReviewQueue(cfg.parseReviewQueue(fusion: fusion))
//    let queued = queue.isQueued(review: merge)
//    try changeQueue(queue: &queue, cfg: cfg, enqueue: false)
//    guard queued else { return true }
//    logMessage(.init(message: "Triggering new pipeline"))
//    try cfg.gitlab
//      .flatReduce(curry: merge.iid, Gitlab.postMrPipelines(review:))
//      .map(execute)
//      .map(Execute.checkStatus(reply:))
//      .get()
//    return true
    #warning("tbd")
    return false
  }
  public func ownReview(cfg: Configuration) throws -> Bool {
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let gitlab = try cfg.gitlab.get()
//    let parent = try gitlab.parent.get()
//    let merge = try gitlab.review.get()
//    guard parent.pipeline.id == merge.lastPipeline.id else {
//      logMessage(.pipelineOutdated)
//      return false
//    }
//    guard try !parseReviewQueue(cfg.parseReviewQueue(fusion: fusion)).isQueued(review: merge) else {
//      logMessage(.init(message: "Review is validating"))
//      return false
//    }
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    guard var status = statuses[merge.iid] else {
//      logMessage(.init(message: "No review \(merge.iid)"))
//      return false
//    }
//    let rules = try parseApprovalRules(cfg.parseApproalRules(approval: fusion.approval))
//    guard try status.setAuthor(job: parent, approvers: gitlab.users, rules: rules)
//    else {
//      logMessage(.init(message: "Already is author: \(parent.user.username)"))
//      return false
//    }
//    statuses[status.review] = status
//    return try persistAsset(.init(
//      cfg: cfg,
//      asset: fusion.approval.statuses,
//      content: Fusion.Approval.Status.serialize(statuses: statuses),
//      message: generate(cfg.createFusionStatusesCommitMessage(fusion: fusion, reason: .own))
//    ))
    #warning("tbd")
    return false
  }
  public func unownReview(cfg: Configuration) throws -> Bool {
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let gitlab = try cfg.gitlab.get()
//    let parent = try gitlab.parent.get()
//    let merge = try gitlab.review.get()
//    guard parent.pipeline.id == merge.lastPipeline.id else {
//      logMessage(.pipelineOutdated)
//      return false
//    }
//    guard try !parseReviewQueue(cfg.parseReviewQueue(fusion: fusion)).isFirst(review: merge) else {
//      logMessage(.init(message: "Review is validating"))
//      return false
//    }
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    guard var status = statuses[merge.iid] else {
//      logMessage(.init(message: "No review \(merge.iid)"))
//      return false
//    }
//    guard try status.unsetAuthor(job: parent, approvers: gitlab.users) else {
//      logMessage(.init(message: "Not an author: \(parent.user.username)"))
//      return false
//    }
//    statuses[status.review] = status
//    return try persistAsset(.init(
//      cfg: cfg,
//      asset: fusion.approval.statuses,
//      content: Fusion.Approval.Status.serialize(statuses: statuses),
//      message: generate(cfg.createFusionStatusesCommitMessage(fusion: fusion, reason: .unown))
//    ))
    #warning("tbd")
    return false
  }
  public func startReplication(cfg: Configuration) throws -> Bool {
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let gitlab = try cfg.gitlab.get()
//    let project = try gitlab.project.get()
//    let merge = try fusion.makeReplication(
//      fork: .make(value: gitlab.job.pipeline.sha),
//      original: .make(name: gitlab.job.pipeline.ref),
//      project: project
//    )
//    let stoppers = try checkMergeStoppers(cfg: cfg, merge: merge)
//    guard stoppers.isEmpty else {
//      stoppers.map(\.logMessage).forEach(logMessage)
//      return false
//    }
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    return try createReview(cfg: cfg, fusion: fusion, statuses: &statuses, merge: merge)
    #warning("tbd")
    return false
  }
  public func startDuplication(
    cfg: Configuration,
    source: String,
    target: String,
    fork: String
  ) throws -> Bool {
    #warning("tbd")
    return false
  }
  public func startIntegration(
    cfg: Configuration,
    source: String,
    target: String,
    fork: String
  ) throws -> Bool {
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let merge = try fusion.makeIntegration(
//      fork: .make(value: fork),
//      original: .make(name: source),
//      target: .make(name: target)
//    )
//    let stoppers = try checkMergeStoppers(cfg: cfg, merge: merge)
//    guard stoppers.isEmpty else {
//      stoppers.map(\.logMessage).forEach(logMessage)
//      return false
//    }
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    return try createReview(cfg: cfg, fusion: fusion, statuses: &statuses, merge: merge)
    #warning("tbd")
    return false
  }
  public func startPropogation(
    cfg: Configuration,
    source: String,
    target: String,
    fork: String
  ) throws -> Bool {
    #warning("tbd")
    return false
  }
  public func renderTargets(cfg: Configuration, args: [String]) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    let parent = try gitlab.parent.get()
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let fork = try Git.Sha.make(job: parent)
//    let source = try Git.Branch.make(job: parent)
//    let targets = try resolveProtectedBranches(cfg: cfg)
//      .filter({ try Execute.parseSuccess(
//        reply: execute(cfg.git.mergeBase(.make(remote: $0), .make(sha: fork)))
//      )})
//      .filter({ try !Execute.parseSuccess(
//        reply: execute(cfg.git.check(child: .make(remote: $0), parent: .make(sha: fork)))
//      )})
//      .map({ branch in try Id
//        .make(cfg.git.check(child: .make(sha: fork), parent: .make(remote: branch)))
//        .map(execute)
//        .map(Execute.parseSuccess(reply:))
//        .map(branch.makeTarget(forward:))
//        .get()
//      })
//    guard targets.isEmpty.not else {
//      logMessage(.init(message: "No branches suitable for integration"))
//      return false
//    }
//    try writeStdout(generate(cfg.exportMergeTargets(
//      fusion: fusion, fork: fork, source: source.name, targets: targets, args: args
//    )))
//    return true
    #warning("tbd")
    return false
  }
  public func closeReview(cfg: Configuration) throws -> Bool {
    #warning("tbd")
    return false
  }
  public func remindReview(cfg: Configuration) throws -> Bool {
    #warning("tbd")
    return false
  }
  public func listReviews(cfg: Configuration, batch: Bool) throws -> Bool {
    #warning("tbd")
    return false
  }
  public func rebaseReview(cfg: Configuration) throws -> Bool {
//    let fusion = try cfg.parseFusion.map(parseFusion).get()
//    let gitlab = try cfg.gitlab.get()
//    let parent = try gitlab.parent.get()
//    let merge = try gitlab.review.get()
//    guard parent.pipeline.id == merge.lastPipeline.id else {
//      #warning("report")
//      logMessage(.pipelineOutdated)
//      return false
//    }
//    guard try checkObsolete(cfg: cfg, review: merge) else {
//      report(cfg.reportReviewObsolete(review: merge))
//      return false
//    }
//    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
//    guard let status = try resolveStatus(cfg: cfg, fusion: fusion, statuses: &statuses)
//    else { return false }
//    guard status.merge.not else { throw Thrown("Rebasing not proposition") }
//    guard try !parseReviewQueue(cfg.parseReviewQueue(fusion: fusion)).isQueued(review: merge) else {
//      #warning("report")
//      logMessage(.init(message: "Review is in queue"))
//      return false
//    }
//
//    #warning("tbd")
//    return false
    #warning("tbd")
    return false
  }
  public func enqueueReview(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let merge = try gitlab.merge.get()
    guard try checkActual(cfg: cfg, merge: merge) else { return false }
    var ctx = try makeContext(cfg: cfg)
    guard var state = try ctx.makeState(merge: merge) else {
      logMessage(.reviewClosed)
      try storeContext(ctx: ctx)
      return false
    }
    guard try performUpdate(ctx: &ctx, state: &state, merge: merge) else {
      try storeContext(ctx: ctx)
      return false
    }
    try storeContext(ctx: ctx)
    return true
  }
  public func acceptReview(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let merge = try gitlab.merge.get()
    guard try checkActual(cfg: cfg, merge: merge) else { return false }
    var ctx = try makeContext(cfg: cfg)
    guard ctx.isFirst(merge: merge) else { return true }
    guard var state = try ctx.makeState(merge: merge) else {
      logMessage(.reviewClosed)
      try storeContext(ctx: ctx)
      return true
    }
    guard try performUpdate(ctx: &ctx, state: &state, merge: merge) else {
      try storeContext(ctx: ctx)
      return true
    }
    guard try acceptReview(ctx: &ctx, state: state) else {
      try storeContext(ctx: ctx)
      return true
    }
    try helpReviews(ctx: &ctx, state: state)
    try storeContext(ctx: ctx)
    return true
  }
}
extension Reviewer {
  func storeContext(ctx: Review.Context) throws {
    #warning("tbd")
  }
  func checkApproves(ctx: Review.Context, state: inout Review.State) throws {
    guard var check = try state.makeApprovesCheck() else { return }
    let head = Git.Ref.make(sha: check.head)
    let excludes = [.make(remote: check.target)] + check.fork.map(Git.Ref.make(sha:)).array
    for sha in try Execute.parseLines(reply: execute(ctx.cfg.git.listCommits(
      in: [head],
      notIn: excludes,
      boundary: true
    ))) {
      let sha = try Git.Sha.make(value: sha)
      check.childs[sha] = try Execute
        .parseLines(reply: execute(ctx.cfg.git.listCommits(
          in: [head],
          notIn: [.make(sha: sha)]
        )))
        .map(Git.Sha.make(value:))
        .reduce(into: Set(), { $0.insert($1) })
    }
    if excludes.count > 1 {
      check.diff += try listMergeChanges(
        cfg: ctx.cfg,
        ref: head,
        parents: excludes
      )
    } else {
      check.diff += try Execute.parseLines(reply: execute(ctx.cfg.git.listChangedFiles(
        source: head,
        target: .make(remote: check.target)
      )))
    }
    for sha in try Execute.parseLines(reply: execute(ctx.cfg.git.listCommits(
      in: [head],
      notIn: excludes
    ))) {
      let sha = try Git.Sha.make(value: sha)
      check.changes[sha] = try listChangedFiles(cfg: ctx.cfg, sha: sha)
    }
    state.update(ctx: ctx, approvesCheck: check)
  }
  func perform(
    cfg: Configuration,
    check: Review.Fusion.GitCheck
  ) throws -> [Review.Problem] {
    var result: [Review.Problem] = []
    switch check {
    case .extraCommits(let branches, let exclude, let head):
      var extras: Set<Git.Branch> = []
      for branch in branches {
        guard let base = try? Execute.parseText(reply: execute(cfg.git.mergeBase(
          .make(remote: branch),
          .make(sha: head)
        ))) else { continue }
        guard try Execute.parseLines(reply: execute(cfg.git.listCommits(
          in: [.make(sha: .make(value: base))],
          notIn: exclude
        ))).isEmpty else { continue }
        extras.insert(branch)
      }
      if extras.isEmpty.not { result.append(.extraCommits(extras)) }
    case .notCherry(let fork, let head, let target):
      guard let pick = try Execute.parseLines(reply: execute(cfg.git.listCommits(
        in: [.make(sha: head)],
        notIn: [.make(remote: target)]
      ))).last else {
        result.append(.notCherry)
        break
      }
      let pickPatchId = try Execute
        .parseText(reply: execute(cfg.git.patchId(ref: .make(sha: .make(value: pick)))))
        .dropSuffix(pick)
      let forkPatchId = try Execute
        .parseText(reply: execute(cfg.git.patchId(ref: .make(sha: fork))))
        .dropSuffix(fork.value)
      if pickPatchId != forkPatchId { result.append(.notCherry) }
    case .notForward(let fork, let head, let target):
      if fork != head { result.append(.sourceNotAtFrok) }
      if try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(sha: fork),
        parent: .make(remote: target)
      ))).not { result.append(.notForward) }
    case .forkInTarget(let fork, let target):
      if try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: target),
        parent: .make(sha: fork)
      ))) { result.append(.forkInTarget) }
    case .forkNotInOriginal(let fork, let original):
      if try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: original),
        parent: .make(sha: fork)
      ))).not { result.append(.forkNotInOriginal) }
    case .forkNotInSource(let fork, let head):
      if try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(sha: head),
        parent: .make(sha: fork)
      ))).not { result.append(.forkNotInOriginal) }
    case .forkParentNotInTarget(let fork, let target):
      if try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: target),
        parent: .make(sha: fork).make(parent: 1)
      ))).not { result.append(.forkParentNotInTarget) }
    }
    return result
  }
  func makeContext(cfg: Configuration) throws -> Review.Context {
    let review = try cfg.parseReview.map(parseReview).get()
    return try .make(
      cfg: cfg,
      review: review,
      rules: parseReviewRules(cfg.parseReviewRules(review: review)),
      storage: parseReviewStorage(cfg.parseReviewStorage(review: review))
    )
  }
  func performUpdate(
    ctx: inout Review.Context,
    state: inout Review.State,
    merge: Json.GitlabMergeState
  ) throws -> Bool {
    let gitlab = try ctx.cfg.gitlab.get()
    let profile = try parseProfile(ctx.cfg.parseProfile(ref: .make(sha: .make(merge: merge))))
    guard try state.prepareChange(
      ctx: ctx,
      merge: merge,
      ownage: ctx.cfg.parseCodeOwnage(profile: profile)
        .map(parseCodeOwnage)
        .get([:]),
      profile: profile
    ) else {
      ctx.update(state: state)
      return false
    }
    try state
      .makeGitCheck(branches: resolveBranches(cfg: ctx.cfg))
      .flatMap({ try perform(cfg: ctx.cfg, check: $0) })
      .forEach({ state.add(problem: $0) })
    try state.update(
      ctx: ctx,
      merge: merge,
      awards: resolveAwards(cfg: ctx.cfg, review: state.review),
      discussions: resolveDiscussions(cfg: ctx.cfg, review: state.review)
    )
    try checkApproves(ctx: ctx, state: &state)
    if let award = state.change?.addAward { try gitlab
      .postMrAward(review: merge.iid, award: award)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    }
    guard state.phase == .ready else {
      ctx.update(state: state)
      return false
    }
    guard try normalize(ctx: ctx, state: &state) else {
      ctx.update(state: state)
      return false
    }
    ctx.update(state: state)
    return ctx.isFirst(merge: merge)
  }
//  func makeUpdate(
//    ctx: inout Review.Context,
//    merge: Json.GitlabMergeState
//  ) throws -> Review.State? {
//    guard let state = try ctx.makeState(merge: merge) else { return nil }
//    let sha = try Git.Ref.make(sha: .make(value: merge.lastPipeline.sha))
//    let profile = try parseProfile(ctx.cfg.parseProfile(ref: sha))
//
//    return try .make(
//      ctx: ctx,
//      merge: merge,
//      ownage: ctx.cfg.parseCodeOwnage(profile: profile)
//        .map(parseCodeOwnage)
//        .get([:]),
//      profile: profile,
//      state: state
//    )
//  }
  func checkActual(
    cfg: Configuration,
    merge: Json.GitlabMergeState
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    let target = try Git.Ref.make(remote: .make(name: merge.targetBranch))
    let head = try Git.Ref.make(sha: .make(merge: merge))
    guard
      let obsolescence = try? parseProfile(cfg.parseProfile(ref: target)).obsolescence,
      try Execute
        .parseLines(reply: execute(cfg.git.listChangedOutsideFiles(source: head, target: target)))
        .contains(where: obsolescence.isMet(_:))
        .not
    else {
      logMessage(.reviewObsolete)
      return false
    }
    return true
  }
//  func resolveStatus(
//    cfg: Configuration,
//    fusion: Fusion,
//    statuses: inout [UInt: Fusion.Approval.Status]
//  ) throws -> Fusion.Approval.Status? {
//    let gitlab = try cfg.gitlab.get()
//    let review = try gitlab.review.get()
//    let bot = try gitlab.rest.get().user
//    if let status = statuses[review.iid] { return status }
//    guard review.state == "opened" else {
//      logMessage(.init(message: "Review state: \(review.state)"))
//      return nil
//    }
//    let status = Fusion.Approval.Status.make(review: review, bot: bot)
//    statuses[status.review] = status
//    _ = try persistAsset(.init(
//      cfg: cfg,
//      asset: fusion.approval.statuses,
//      content: Fusion.Approval.Status.serialize(statuses: statuses),
//      message: generate(cfg.createFusionStatusesCommitMessage(fusion: fusion, reason: .create))
//    ))
//    report(cfg.reportReviewCreated(status: status, review: review))
//    return status
//  }
//  func resolveOwnage(
//    cfg: Configuration,
//    state: Json.GitlabReviewState
//  ) -> [String: Criteria] {
//    do { return try Id(state.lastPipeline.sha)
//      .map(Git.Sha.make(value:))
//      .map(Git.Ref.make(sha:))
//      .map(cfg.parseProfile(ref:))
//      .map(parseProfile)
//      .map(cfg.parseCodeOwnage(profile:))
//      .get()
//      .map(parseCodeOwnage)
//      .get([:])
//    } catch { return [:] }
//  }
//  func resolveReview(
//    cfg: Configuration,
//    fusion: Fusion,
//    status: Fusion.Approval.Status,
//    review: Json.GitlabReviewState? = nil
//  ) throws -> Review? {
//    logMessage(.init(message: "Loading status assets"))
//    let gitlab = try cfg.gitlab.get()
//    let review = try gitlab.review.get()
//    guard let infusion = try resolveInfusion(cfg: cfg, fusion: fusion, status: status)
//    else { return nil }
//    let result = try Review.make(
//      bot: cfg.gitlab.get().rest.get().user.username,
//      status: status,
//      approvers: gitlab.users,
//      review: review,
//      infusion: infusion,
//      blockers: checkReviewBlockers(cfg: cfg, infusion: infusion),
//      ownage: resolveOwnage(cfg: cfg, state: review),
//      rules: parseApprovalRules(cfg.parseApproalRules(approval: fusion.approval)),
//      haters: cfg.parseHaters(approval: fusion.approval)
//        .map(parseHaters)
//        .get([:])
//    )
//    var stoppers = result.stoppers
//    if let sanity = result.rules.sanity {
//      if cfg.profile.checkSanity(criteria: result.ownage[sanity]).not { stoppers.append(.sanity) }
//    }
//    guard result.stoppers.isEmpty else {
//      report(cfg.reportReviewStopped(
//        status: status,
//        infusion: infusion,
//        reasons: stoppers,
//        unknownUsers: result.unknownUsers,
//        unknownTeams: result.unknownTeams
//      ))
//      return nil
//    }
//    return result
//  }
//  func verify(
//    cfg: Configuration,
//    state: Json.GitlabReviewState,
//    fusion: Fusion,
//    review: inout Review
//  ) throws -> Review.Approval {
//    logMessage(.init(message: "Validating approves"))
//    let fork = review.infusion.merge
//      .map(\.fork)
//      .map(Git.Ref.make(sha:))
//    let current = try Git.Sha.make(value: state.lastPipeline.sha)
//    let target = try Git.Ref.make(remote: .make(name: state.targetBranch))
//    if let fork = review.infusion.merge?.fork {
//      try review.resolveOwnage(diff: listMergeChanges(
//        cfg: cfg,
//        ref: .make(sha: current),
//        parents: [target, .make(sha: fork)]
//      ))
//    } else {
//      try review.resolveOwnage(diff: Execute.parseLines(
//        reply: execute(cfg.git.listChangedFiles(
//          source: .make(sha: current),
//          target: target
//        ))
//      ))
//    }
//    for sha in try Execute.parseLines(reply: execute(cfg.git.listCommits(
//      in: [.make(sha: current)],
//      notIn: [target] + fork.array
//    ))) {
//      let sha = try Git.Sha.make(value: sha)
//      try review.addChanges(sha: sha, diff: listChangedFiles(cfg: cfg, state: state, sha: sha))
//    }
//    for sha in review.status.approvedCommits { try review.addBreakers(
//      sha: sha,
//      commits: Execute
//        .parseLines(reply: execute(cfg.git.listCommits(
//          in: [.make(sha: current)],
//          notIn: [target, .make(sha: sha)] + fork.array,
//          ignoreMissing: true
//        )))
//        .map(Git.Sha.make(value:))
//    )}
//    return review.resolveApproval(sha: current)
//  }
//  func checkMergeStoppers(
//    cfg: Configuration,
//    merge: Review.State.Infusion.Merge
//  ) throws -> [Report.ReviewStopped.Reason] {
//    var result: [Report.ReviewStopped.Reason] = []
//    if try Execute.parseSuccess(reply: execute(cfg.git.check(
//      child: .make(remote: merge.target),
//      parent: .make(sha: merge.fork)
//    ))) { result.append(.forkInTarget) }
//    if try Execute.parseSuccess(reply: execute(cfg.git.check(
//      child: .make(remote: merge.original),
//      parent: .make(sha: merge.fork)
//    ))).not { result.append(.forkNotInOriginal) }
//    guard .replicate == merge.prefix else { return result }
//    if try Execute.parseSuccess(reply: execute(cfg.git.check(
//      child: .make(remote: merge.target),
//      parent: .make(sha: merge.fork).make(parent: 1)
//    ))).not { result.append(.forkParentNotInTarget) }
//    return result
//  }
//  func resolveInfusion(
//    cfg: Configuration,
//    fusion: Fusion,
//    status: Fusion.Approval.Status
//  ) throws -> Review.State.Infusion? {
//    let gitlab = try cfg.gitlab.get()
//    let review = try gitlab.review.get()
//    let project = try gitlab.project.get()
//    let bot = try gitlab.rest.get().user.username
//    let state = try fusion.makeReviewState(status: status, review: review, project: project)
//    logMessage(.init(message: "Checking review stoppers"))
//    var reasons: [Report.ReviewStopped.Reason] = []
//    var infusion: Review.State.Infusion? = nil
//    switch state {
//    case .confusion(.undefinedInfusion):
//      reasons.append(.noSourceRule)
//    case .confusion(.multipleInfusions(let rules)):
//      reasons.append(.multipleRules)
//      logMessage(.init(message: "Multiple rules: \(rules.joined(separator: ", "))"))
//    case .confusion(.sourceFormat):
//      reasons.append(.sourceFormat)
//    case .infusion(let value): infusion = value
//    }
//    guard let infusion = infusion else {
//      report(cfg.reportReviewStopped(status: status, infusion: nil, reasons: reasons))
//      reasons.map(\.logMessage).forEach(logMessage)
//      return nil
//    }
//    let source = try resolveBranch(cfg: cfg, name: infusion.source.name)
//    if source.protected { reasons.append(.sourceIsProtected) }
//    let target = try resolveBranch(cfg: cfg, name: review.targetBranch)
//    if target.protected.not { reasons.append(.targetNotProtected) }
//    let excludes: [Git.Ref]
//    switch infusion {
//    case .squash:
//      if review.author.username == bot { reasons.append(.botSquash) }
//      try excludes = [.make(remote: .make(name: review.targetBranch))]
//    case .merge(let merge):
//      reasons += try checkMergeStoppers(cfg: cfg, merge: merge)
//      if review.author.username != bot { reasons.append(.notBotMerge) }
//      if try !Execute.parseSuccess(reply: execute(cfg.git.check(
//        child: .make(remote: merge.source),
//        parent: .make(sha: merge.fork)
//      ))) { reasons.append(.forkNotInSource) }
//      if merge.prefix == .replicate, target.default.not { reasons.append(.targetNotDefault) }
//      let original = try resolveBranch(cfg: cfg, name: merge.original.name)
//      if original.protected.not { reasons.append(.originalNotProtected) }
//      if review.targetBranch != merge.target.name { reasons.append(.forkTargetMismatch) }
//      excludes = [.make(remote: merge.target), .make(sha: merge.fork)]
//    }
//    let head = try Git.Sha.make(value: review.lastPipeline.sha)
//    for branch in try resolveProtectedBranches(cfg: cfg) {
//      guard let base = try? Execute.parseText(reply: execute(cfg.git.mergeBase(
//        .make(remote: branch),
//        .make(sha: head)
//      ))) else { continue }
//      let extras = try Execute.parseLines(reply: execute(cfg.git.listCommits(
//        in: [.make(sha: .make(value: base))],
//        notIn: excludes
//      )))
//      guard extras.isEmpty else {
//        reasons.append(.extraCommits)
//        break
//      }
//    }
//    guard reasons.isEmpty else {
//      report(cfg.reportReviewStopped(status: status, infusion: infusion, reasons: reasons))
//      reasons.map(\.logMessage).forEach(logMessage)
//      return nil
//    }
//    return infusion
//  }
//  func checkReviewBlockers(
//    cfg: Configuration,
//    infusion: Review.State.Infusion
//  ) throws -> [Report.ReviewUpdated.Blocker] {
//    let merge = try cfg.gitlab.get().review.get()
//    logMessage(.init(message: "Checking blocking reasons"))
//    var result: [Report.ReviewUpdated.Blocker] = []
//    if merge.draft { result.append(.draft) }
//    if merge.workInProgress { result.append(.workInProgress) }
//    if !merge.blockingDiscussionsResolved { result.append(.discussions) }
//    switch infusion {
//    case .squash(let squash):
//      if !merge.squash { result.append(.squashStatus) }
//      if let title = squash.proposition.title, !title.isMet(merge.title)
//      { result.append(.badTitle) }
//      if let task = squash.proposition.task {
//        let source = try merge.sourceBranch.find(matches: task)
//        let title = try merge.title.find(matches: task)
//        if Set(source).symmetricDifference(title).isEmpty.not { result.append(.taskMismatch) }
//      }
//    case .merge:
//      if merge.squash { result.append(.squashStatus) }
//    }
//    return result
//  }
//  func checkIsFastForward(
//    cfg: Configuration,
//    state: Json.GitlabReviewState
//  ) throws -> Bool {
//    logMessage(.init(message: "Checking fast forward state"))
//    return try Execute.parseSuccess(reply: execute(cfg.git.check(
//      child: .make(sha: .make(value: state.lastPipeline.sha)),
//      parent: .make(remote: .make(name: state.targetBranch))
//    )))
//  }
  func normalize(
    ctx: Review.Context,
    state: inout Review.State
  ) throws -> Bool {
    guard let change = state.change else { return false }
    switch change.fusion {
    case .propose:
      return try syncReview(ctx: ctx, state: &state)
    case .replicate(let replicate):
      return try squashReview(ctx: ctx, state: &state, fork: replicate.fork)
    case .integrate(let integrate):
      return try squashReview(ctx: ctx, state: &state, fork: integrate.fork)
    case .duplicate(let duplicate):
      let commits = try Execute.parseLines(reply: execute(ctx.cfg.git.listCommits(
        in: [.make(sha: change.head)],
        notIn: [.make(remote: duplicate.target)]
      )))
      guard let fork = try commits.last.map(Git.Sha.make(value:)) else { return false }
      return try squashReview(ctx: ctx, state: &state, fork: fork)
    case .propogate: return true
    }
  }
  func syncReview(
    ctx: Review.Context,
    state: inout Review.State
  ) throws -> Bool {
    guard let change = state.change else { return false }
    guard try Execute.parseSuccess(reply: execute(ctx.cfg.git.check(
      child: .make(sha: change.head),
      parent: .make(remote: change.fusion.target)
    ))).not else { return true }
    if let sha = try mergeReview(
      cfg: ctx.cfg,
      commit: .make(remote: change.fusion.target),
      into: .make(sha: change.head),
      message: "Merge \(change.fusion.target.name) into \(change.fusion.source.name)"
    ) {
      let gitlab = try ctx.cfg.gitlab.get()
      let rest = try gitlab.rest.get()
      try Execute.checkStatus(reply: execute(ctx.cfg.git.push(
        url: rest.push,
        branch: state.source,
        sha: sha,
        force: false,
        secret: rest.secret
      )))
      state.shiftHead(sha: sha)
    } else {
      state.add(problem: .conflicts)
    }
    return false
  }
  func squashReview(
    ctx: Review.Context,
    state: inout Review.State,
    fork: Git.Sha
  ) throws -> Bool {
    guard let change = state.change else { return false }
    let target = try Execute.parseText(reply: execute(ctx.cfg.git.getSha(
      ref: .make(remote: state.target)
    )))
    let parents = try Execute.parseLines(reply: execute(ctx.cfg.git.listParents(
      ref: .make(sha: change.head)
    )))
    guard parents != [target, fork.value] else { return true }
    let gitlab = try ctx.cfg.gitlab.get()
    let rest = try gitlab.rest.get()
    let fork = Git.Ref.make(sha: fork)
    let message = "Merge \(state.target.name) into \(state.source.name)"
    guard var head = try mergeReview(
      cfg: ctx.cfg,
      commit: .make(remote: state.target),
      into: fork,
      message: message
    ) else {
      state.add(problem: .conflicts)
      return false
    }
    head = try .make(value: Execute.parseText(reply: execute(ctx.cfg.git.commitTree(
      tree: .init(ref: .make(sha: head)),
      message: message,
      parents: [.make(remote: state.target), fork],
      env: Git.env(
        authorName: Execute.parseText(reply: execute(ctx.cfg.git.getAuthorName(ref: fork))),
        authorEmail: Execute.parseText(reply: execute(ctx.cfg.git.getAuthorEmail(ref: fork))),
        commiterName: Execute.parseText(reply: execute(ctx.cfg.git.getCommiterName(ref: fork))),
        commiterEmail: Execute.parseText(reply: execute(ctx.cfg.git.getCommiterEmail(ref: fork)))
      )
    ))))
    try Execute.checkStatus(reply: execute(ctx.cfg.git.push(
      url: rest.push,
      branch: state.source,
      sha: head,
      force: true,
      secret: rest.secret
    )))
    state.shiftHead(sha: head)
    state.squashApproves(sha: head)
    return false
  }
  func listChangedFiles(
    cfg: Configuration,
    sha: Git.Sha
  ) throws -> [String] {
    let sha = Git.Ref.make(sha: sha)
    let parents = try Execute.parseLines(reply: execute(cfg.git.listParents(ref: sha)))
    if parents.count > 1 {
      return try listMergeChanges(
        cfg: cfg,
        ref: sha,
        parents: parents
          .map(Git.Sha.make(value:))
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
      ref: .make(sha: .make(value: initial))
    )))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    return result
  }
//  func changeQueue(
//    queue: inout Fusion.Queue,
//    cfg: Configuration,
//    enqueue: Bool
//  ) throws {
//    let review = try cfg.gitlab.get().review.get()
//    if enqueue { logMessage(.init(message: "Enqueueing review")) }
//    else { logMessage(.init(message: "Dequeueing review")) }
//    let gitlab = try cfg.gitlab.get()
//    let notifiables = queue.enqueue(
//      review: review.iid,
//      target: enqueue.then(review.targetBranch)
//    )
//    let message = try generate(cfg.createReviewQueueCommitMessage(queue: queue, queued: enqueue))
//    let result = try persistAsset(.init(
//      cfg: cfg,
//      asset: queue.asset,
//      content: queue.yaml,
//      message: message
//    ))
//    for notifiable in notifiables {
//      try Execute.checkStatus(reply: execute(gitlab.postMrPipelines(review: notifiable).get()))
//    }
//  }
  func pickReview(
    cfg: Configuration,
    sha: Git.Sha,
    target: Git.Branch
  ) throws -> Git.Sha? {
    let initial = try Id(.head)
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let sha = Git.Ref.make(sha: sha)
    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: .make(remote: target))))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    do {
      try Execute.checkStatus(reply: execute(cfg.git.cherry(ref: sha)))
    } catch {
      try Execute.checkStatus(reply: execute(cfg.git.quitCherry))
      try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: initial)))
      try Execute.checkStatus(reply: execute(cfg.git.clean))
      return nil
    }
    try Execute.checkStatus(reply: execute(cfg.git.addAll))
    try Execute.checkStatus(reply: execute(cfg.git.commit(
      message: Execute.parseText(reply: execute(cfg.git.getCommitMessage(ref: sha))),
      env: Git.env(
        authorName: Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: sha))),
        authorEmail: Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: sha))),
        commiterName: Execute.parseText(reply: execute(cfg.git.getCommiterName(ref: sha))),
        commiterEmail: Execute.parseText(reply: execute(cfg.git.getCommiterEmail(ref: sha)))
      )
    )))
    let result = try Id(.head)
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.make(value:))
      .get()
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: initial)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    return result
  }
  func mergeReview(
    cfg: Configuration,
    commit: Git.Ref,
    into first: Git.Ref,
    message: String
  ) throws -> Git.Sha? {
    logMessage(.init(message: "Merging target into source"))
    let initial = try Id(.head)
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let name = try Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: first)))
    let email = try Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: first)))
    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: first)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    do {
      try Execute.checkStatus(reply: execute(cfg.git.merge(
        refs: [commit],
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
      #warning("adopt to empty diff merges")
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
      .map(Git.Sha.make(value:))
      .get()
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: initial)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    return result
  }
  func acceptReview(
    ctx: inout Review.Context,
    state: Review.State
  ) throws -> Bool {
    guard let change = state.change else { throw MayDay("Unexpected merge state") }
    let params: Gitlab.PutMrMerge
    switch change.fusion {
    case .propose: params = try .init(
      squashCommitMessage: generate(ctx.cfg.createMergeCommitMessage(
        review: ctx.review,
        fusion: change.fusion
      )),
      squash: true,
      shouldRemoveSourceBranch: true,
      sha: change.head
    )
    case .replicate, .integrate, .duplicate: params = try .init(
      mergeCommitMessage: generate(ctx.cfg.createMergeCommitMessage(
        review: ctx.review,
        fusion: change.fusion
      )),
      squash: false,
      shouldRemoveSourceBranch: true,
      sha: change.head
    )
    case .propogate: params = .init(
      squash: false,
      shouldRemoveSourceBranch: true,
      sha: change.head
    )}
    let gitlab = try ctx.cfg.gitlab.get()
    let result = try gitlab
      .putMrMerge(parameters: params, review: state.review)
      .map(execute)
      .map(\.data)
      .get()
      .reduce(AnyCodable.self, jsonDecoder.decode(_:from:))
    if case "merged"? = result?.map?["state"]?.value?.string {
      logMessage(.init(message: "Review merged"))
      ctx.merge(merge: change.merge)
      return true
    } else if let message = result?.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      ctx.dequeue(merge: change.merge)
      return false
    } else {
      logMessage(.init(message: "Unexpected merge response"))
      ctx.dequeue(merge: change.merge)
      return false
    }
  }
  func helpReviews(ctx: inout Review.Context, state: Review.State) throws {
//    if let obsolescence = ctx.cfg.profile.obsolescence, try Execute
//      .parseLines(reply: execute(ctx.cfg.git.listChangedFiles(
//        source: .make(sha: update.head),
//        target: .make(remote: .make(name: update.merge.targetBranch))
//      )))
//      .contains(where: obsolescence.isMet(_:))
//    {
//      var synced: Set<UInt> = []
//      for iid in ctx.storage.queues[update.merge.targetBranch].get([]) {
//        guard var state = ctx.storage.states[iid] else { continue }
////        guard let sha =
//        #warning("tbd")
//        synced.insert(iid)
//      }
//      for var state in ctx.storage.states.values {
//        guard state.target == update.state.target else { continue }
//        guard synced.contains(state.review).not else { continue }
//        #warning("tbd")
//
//      }
//    }
    #warning("tbd")
  }
//  func shiftReplication(
//    cfg: Configuration,
//    fusion: Fusion,
//    infusion: Review.State.Infusion
//  ) throws -> Review.State.Infusion.Merge? {
//    let project = try cfg.gitlab.get().project.get()
//    guard let merge = infusion.merge, merge.prefix == .replicate else { return nil }
//    let fork = try Id
//      .make(cfg.git.listCommits(
//        in: [.make(remote: merge.original)],
//        notIn: [.make(sha: merge.fork)],
//        firstParents: true
//      ))
//      .map(execute)
//      .map(Execute.parseLines(reply:))
//      .get()
//      .last
//      .map(Git.Sha.make(value:))
//    guard let fork = fork else { return nil }
//    return try fusion.makeReplication(fork: fork, original: merge.original, project: project)
//  }
//  func createReview(
//    cfg: Configuration,
//    fusion: Fusion,
//    statuses: inout [UInt: Fusion.Approval.Status],
//    merge: Review.State.Infusion.Merge
//  ) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    let rest = try gitlab.rest.get()
//    guard try !Execute.parseSuccess(reply: execute(cfg.git.checkObjectType(
//      ref: .make(remote: merge.source)
//    ))) else {
//      logMessage(.init(message: "Merge already in progress"))
//      return false
//    }
//    try Id
//      .make(cfg.git.push(
//        url: rest.push,
//        branch: merge.source,
//        sha: merge.fork,
//        force: false,
//        secret: rest.secret
//      ))
//      .map(execute)
//      .map(Execute.checkStatus(reply:))
//      .get()
//    let reivew = try gitlab
//      .postMergeRequests(parameters: .init(
//        sourceBranch: merge.source.name,
//        targetBranch: merge.target.name,
//        title: generate(cfg.createMergeCommitMessage(fusion: fusion, infusion: .merge(merge)))
//      ))
//      .map(execute)
//      .map(Execute.parseData(reply:))
//      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(_:from:))
//      .get()
//    let status = try Fusion.Approval.Status.make(
//      review: reivew,
//      bot: rest.user,
//      authors: resolveAuthors(cfg: cfg, merge: merge),
//      merge: merge
//    )
//    report(cfg.reportReviewCreated(status: status, review: reivew))
//    statuses[status.review] = status
//    return try persistAsset(.init(
//      cfg: cfg,
//      asset: fusion.approval.statuses,
//      content: Fusion.Approval.Status.serialize(statuses: statuses),
//      message: generate(cfg.createFusionStatusesCommitMessage(fusion: fusion, reason: .create))
//    ))
//  }
//  func resolveBranch(cfg: Configuration, name: String) throws -> Json.GitlabBranch { try cfg
//      .gitlab
//      .flatReduce(curry: name, Gitlab.getBranch(name:))
//      .map(execute)
//      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(success:reply:))
//      .get()
//  }
  func resolveBranches(cfg: Configuration) throws -> [Json.GitlabBranch] {
    var result: [Json.GitlabBranch] = []
    var page = 1
    let gitlab = try cfg.gitlab.get()
    while true {
      let branches = try gitlab
        .getBranches(page: page, count: 100)
        .map(execute)
        .reduce([Json.GitlabBranch].self, jsonDecoder.decode(success:reply:))
        .get()
      result += branches
      guard branches.count == 100 else { return result }
      page += 1
    }
  }
  func resolveAwards(cfg: Configuration, review: UInt) throws -> [Json.GitlabAward] {
    var result: [Json.GitlabAward] = []
    var page = 1
    let gitlab = try cfg.gitlab.get()
    while true {
      let awarders = try gitlab.getMrAwarders(review: review, page: page, count: 100)
        .map(execute)
        .reduce([Json.GitlabAward].self, jsonDecoder.decode(success:reply:))
        .get()
      result += awarders
      guard awarders.count == 100 else { return result }
      page += 1
    }
  }
  func resolveDiscussions(cfg: Configuration, review: UInt) throws -> [Json.GitlabDiscussion] {
    var result: [Json.GitlabDiscussion] = []
    var page = 1
    let gitlab = try cfg.gitlab.get()
    while true {
      let discussions = try gitlab.getMrDiscussions(review: review, page: page, count: 100)
        .map(execute)
        .reduce([Json.GitlabDiscussion].self, jsonDecoder.decode(success:reply:))
        .get()
      result += discussions
      guard discussions.count == 100 else { return result }
      page += 1
    }
  }
//  func resolveAuthors(
//    cfg: Configuration,
//    merge: Review.State.Infusion.Merge
//  ) throws -> Set<String> {
//    let gitlab = try cfg.gitlab.get()
//    let commits = try Execute.parseLines(reply: execute(cfg.git.listCommits(
//      in: [.make(sha: merge.fork)],
//      notIn: [.make(remote: merge.target)],
//      noMerges: true
//    )))
//    var result: Set<String> = []
//    for commit in commits { try gitlab
//      .listShaMergeRequests(sha: .make(value: commit))
//      .map(execute)
//      .reduce([Json.GitlabCommitMergeRequest].self, jsonDecoder.decode(success:reply:))
//      .get()
//      .filter { $0.projectId == gitlab.job.pipeline.projectId }
//      .filter { $0.squashCommitSha == commit }
//      .forEach { result.insert($0.author.username) }
//    }
//    return result
//  }
}
