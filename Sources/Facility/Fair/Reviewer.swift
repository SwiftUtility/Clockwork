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
  let parseStdin: Try.Reply<Configuration.ParseStdin>
  let readStdin: Try.Do<Data?>
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
    parseStdin: @escaping Try.Reply<Configuration.ParseStdin>,
    readStdin: @escaping Try.Do<Data?>,
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
    self.parseStdin = parseStdin
    self.readStdin = readStdin
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func signal(
    cfg: Configuration,
    event: String,
    stdin: Configuration.ParseStdin,
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
    var ctx = try makeContext(cfg: cfg)
    for iid in ctx.storage.queues.values.compactMap(\.first) {
      guard let merge = try getMerge(cfg: cfg, iid: iid) else { continue }
      if merge.lastPipeline.isFailed { ctx.dequeue(merge: merge) }
    }
    for state in ctx.storage.states.values {
      guard
        state.phase == .stuck,
        let merge = try getMerge(cfg: cfg, iid: state.review),
        var state = try ctx.makeState(merge: merge),
        try state.prepareChange(ctx: ctx, merge: merge),
        state.problems.get([]).isEmpty
      else { continue }
      try state.update(
        ctx: ctx,
        merge: merge,
        awards: resolveAwards(cfg: ctx.cfg, review: state.review),
        discussions: []
      )
      if state.problems.get([]).isEmpty { ctx.trigger.insert(state.review) }
    }
    try storeContext(ctx: &ctx)
    return true
  }
  public func patchReview(
    cfg: Configuration,
    skip: Bool,
    message: String
  ) throws -> Bool {
    guard let patch = try readStdin() else { return false }
    guard let merge = try checkActual(cfg: cfg) else { return false }
    var ctx = try makeContext(cfg: cfg)
    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
    guard let sha = try apply(
      cfg: cfg,
      patch: patch,
      message: message,
      to: .make(sha: .make(merge: merge))
    ) else {
      report(cfg.report(notify: .patchFailed, merge: merge))
      return false
    }
    state.skip.insert(sha)
    try storeChange(ctx: ctx, state: state, merge: merge)
    return true
  }
  public func skipReview(
    cfg: Configuration,
    iid: UInt
  ) throws -> Bool {
    guard let merge = try getMerge(cfg: cfg, iid: iid) else { return false }
    var ctx = try makeContext(cfg: cfg)
    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
    let sha = try Git.Sha.make(merge: merge)
    guard state.verified != sha else {
      report(cfg.report(notify: .skipFailed, merge: merge))
      return false
    }
    state.verified = sha
    try storeChange(ctx: ctx, state: state, merge: merge)
    return true
  }
  public func approveReview(cfg: Configuration, advance: Bool) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let merge = try gitlab.merge.get()
    var ctx = try makeContext(cfg: cfg)
    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
    guard try state.approve(job: gitlab.parent.get(), advance: advance) else {
      report(cfg.report(notify: .approveFailed, merge: merge))
      return false
    }
    try storeChange(ctx: ctx, state: state, merge: merge)
    return true
  }
  public func dequeueReview(cfg: Configuration, iid: UInt) throws -> Bool {
    guard let merge = try getMerge(cfg: cfg, iid: iid) else { return false }
    var ctx = try makeContext(cfg: cfg)
    ctx.dequeue(merge: merge)
    try storeContext(ctx: &ctx, skip: merge.iid)
    return true
  }
  public func ownReview(cfg: Configuration, user: String, iid: UInt) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    guard let merge = try getMerge(cfg: cfg, iid: (iid > 0).then(iid)) else { return false }
    var ctx = try makeContext(cfg: cfg)
    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
    let user = user.isEmpty.not.then(user).get(gitlab.job.user.username)
    guard state.authors.insert(user).inserted else {
      report(cfg.report(notify: .unownFailed, merge: merge))
      return false
    }
    try storeChange(ctx: ctx, state: state, merge: merge)
    return true
  }
  public func unownReview(cfg: Configuration, user: String, iid: UInt) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    guard let merge = try getMerge(cfg: cfg, iid: (iid > 0).then(iid)) else { return false }
    var ctx = try makeContext(cfg: cfg)
    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
    let user = user.isEmpty.not.then(user).get(gitlab.job.user.username)
    guard state.authors.remove(user) != nil else {
      report(cfg.report(notify: .ownFailed, merge: merge))
      return false
    }
    try storeChange(ctx: ctx, state: state, merge: merge)
    return true
  }
  public func startFusion(
    cfg: Configuration,
    prefix: Review.Fusion.Prefix,
    source: String,
    target: String,
    fork: String
  ) throws -> Bool {
    let review = try cfg.parseReview.map(parseReview).get()
    guard let fusion = try makeFusion(
      cfg: cfg, review: review, prefix: prefix, target: target, source: source, fork: fork
    ) else { return true }
    var head = try Git.Sha.make(value: fork)
    let pick: Git.Sha?
    if prefix == .duplicate {
      guard let commit = try cherry(cfg: cfg, sha: head, to: .make(remote: fusion.target)) else {
        report(cfg.report(notify: .make(prefix: prefix)))
        return false
      }
      pick = commit
      head = commit
    } else {
      pick = nil
    }
    if prefix == .propogate {
      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(sha: head),
        parent: .make(remote: fusion.target)
      ))) else {
        report(cfg.report(notify: .make(prefix: prefix)))
        return false
      }
    } else {
      head = try squashPoint(cfg: cfg, fusion: fusion, fork: head, head: head).get(head)
    }
    return try createReview(cfg: cfg, review: review, fusion: fusion, head: head, pick: pick)
  }
  public func renderTargets(cfg: Configuration, args: [String]) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let review = try cfg.parseReview.map(parseReview).get()
    let fork = try Git.Sha.make(job: parent)
    let ref = Git.Ref.make(sha: fork)
    let source = try Git.Branch.make(job: parent)
    let targets = try resolveBranches(cfg: cfg).reduce(into: [String: Bool](), { result, target in
      let remote = try Git.Ref.make(remote: .make(name: target.name))
      guard
        target.protected,
        result[target.name] == nil,
        try Execute.parseSuccess(reply: execute(cfg.git.mergeBase(remote, ref))),
        try !Execute.parseSuccess(reply: execute(cfg.git.check(child: remote, parent: ref)))
      else { return }
      result[target.name] = try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: ref,
        parent: remote
      )))
    })
    let integrate = targets.keys.map(\.alphaNumeric).sorted().map(\.value)
    let duplicate = try Execute.parseLines(reply: execute(cfg.git.listParents(ref: ref))).count == 1
    try writeStdout(generate(cfg.exportTargets(
      review: review,
      fork: fork,
      source: source.name,
      integrate: integrate,
      duplicate: duplicate.then(integrate).get([]),
      propogate: integrate.filter({ targets[$0] == true }),
      args: args
    )))
    return true
  }
  public func remindReview(cfg: Configuration, iid: UInt) throws -> Bool {
    guard let merge = try getMerge(cfg: cfg, iid: (iid > 0).then(iid)) else { return false }
    var ctx = try makeContext(cfg: cfg)
    guard let state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
    guard state.verified != nil else {
      report(cfg.report(notify: .nothingToApprove))
      return false
    }
    for user in state.approvers.filter(state.isUnapproved(user:)) {
      let approve = ctx.remind(review: state.review, user: user)
      report(cfg.reportReviewApprove(user: user, merge: merge, approve: approve))
    }
    return true
  }
  public func listReviews(cfg: Configuration, user: String) throws -> Bool {
    let ctx = try makeContext(cfg: cfg)
    let users = user.isEmpty.then(ctx.approvers).get([user])
    var reviews: [UInt: Set<String>] = [:]
    for state in ctx.storage.states.values {
      guard state.verified != nil else { continue }
      reviews[state.review] = state.approvers.intersection(users).filter(state.isUnapproved(user:))
    }
    for user in users {
      let reviews = reviews
        .filter({ $0.value.contains(user) })
        .keys
        .reduce(into: [:], { $0[$1] = ctx.remind(review: $1, user: user) })
      if reviews.isEmpty {
        report(cfg.report(notify: .nothingToApprove, user: user))
      } else {
        report(cfg.reportReviewList(user: user, reviews: reviews))
      }
    }
    return true
  }
  public func rebaseReview(cfg: Configuration, iid: UInt) throws -> Bool {
    guard let merge = try getMerge(cfg: cfg, iid: (iid > 0).then(iid)) else { return false }
    var ctx = try makeContext(cfg: cfg)
    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
    _ = try checkReady(ctx: &ctx, state: &state, merge: merge)
    guard let change = state.change, state.canRebase else {
      report(cfg.report(notify: .rebaseBlocked, merge: merge))
      return false
    }
    var head = Git.Ref.make(sha: change.head)
    let target = Git.Ref.make(remote: change.fusion.target)
    var commit = try Git.Sha.make(value: Execute.parseText(reply: execute(cfg.git.mergeBase(
      target,
      head
    ))))
    for sha in try Execute.parseLines(reply: execute(cfg.git.listCommits(
      in: [target],
      notIn: [head]
    ))) {
      let sha = try Git.Sha.make(value: sha)
      guard let merge = try mergeReview(
        cfg: cfg,
        commit: .make(sha: sha),
        into: head,
        message: "Temp"
      ) else { continue }
      head = .make(sha: merge)
      commit = sha
      break
    }
    for sha in try Execute
      .parseLines(reply: execute(cfg.git.listCommits(in: [head], notIn: [target])))
      .map(Git.Sha.make(value:))
      .reversed()
    {
      let skip = state.skip.remove(sha) != nil
      if let pick = try cherry(cfg: cfg, sha: sha, to: .make(sha: commit)) {
        if skip { state.skip.insert(pick) }
        commit = pick
      }
      state.approves.keys.forEach({ state.approves[$0]?.shift(sha: sha, to: commit) })
    }
    if try isEqualTree(cfg: cfg, tree: commit, to: change.head).not {
      commit = try .make(value: Execute.parseText(reply: execute(cfg.git.commitTree(
        tree: .init(ref: head),
        message: "Squash unpickable commits",
        parents: [.make(sha: commit)],
        env: [:]
      ))))
      state.skip.insert(commit)
    }
    state.shiftHead(to: commit)
    ctx.update(state: state)
    let rest = try cfg.gitlab.flatMap(\.rest).get()
    try Execute.checkStatus(reply: execute(ctx.cfg.git.push(
      url: rest.push,
      branch: change.fusion.source,
      sha: change.head,
      force: true,
      secret: rest.secret
    )))
    try storeContext(ctx: &ctx, skip: iid)
    return true
  }
  public func enqueueReview(cfg: Configuration) throws -> Bool {
    guard let merge = try checkActual(cfg: cfg) else { return false }
    var ctx = try makeContext(cfg: cfg)
    guard
      var state = try ctx.makeState(merge: merge),
      try checkReady(ctx: &ctx, state: &state, merge: merge),
      try normalize(ctx: &ctx, state: &state)
    else {
      try storeContext(ctx: &ctx, skip: merge.iid)
      return false
    }
    try storeContext(ctx: &ctx, skip: merge.iid)
    return true
  }
  public func acceptReview(cfg: Configuration) throws -> Bool {
    guard let merge = try checkActual(cfg: cfg) else { return true }
    var ctx = try makeContext(cfg: cfg)
    if ctx.isFirst(merge: merge).not {
      ctx.trigger.insert(merge.iid)
    } else if
      var state = try ctx.makeState(merge: merge),
      try checkReady(ctx: &ctx, state: &state, merge: merge),
      try normalize(ctx: &ctx, state: &state),
      try acceptReview(ctx: &ctx, state: state)
    {
      try helpReviews(ctx: &ctx, state: state)
    }
    try storeContext(ctx: &ctx)
    return true
  }
}
extension Reviewer {
  func getMerge(cfg: Configuration, iid: UInt?) throws -> Json.GitlabMergeState? {
    if let iid = iid {
      let gitlab = try cfg.gitlab.get()
      return try gitlab
        .getMrState(review: iid)
        .map(execute)
        .reduce(Json.GitlabMergeState.self, jsonDecoder.decode(success:reply:))
        .get()
    } else { return try checkActual(cfg: cfg) }
  }
  func createReview(
    cfg: Configuration,
    review: Review,
    fusion: Review.Fusion,
    head: Git.Sha,
    pick: Git.Sha? = nil
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let rest = try gitlab.rest.get()
    try Execute.checkStatus(reply: execute(cfg.git.push(
      url: rest.push, branch: fusion.source, sha: head, force: false, secret: rest.secret
    )))
    let title = try generate(cfg.createMergeCommitMessage(
      merge: nil, review: review, fusion: fusion
    ))
    let merge = try gitlab
      .postMergeRequests(parameters: .init(
        sourceBranch: fusion.source.name, targetBranch: fusion.target.name, title: title
      ))
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabMergeState.self, jsonDecoder.decode(_:from:))
      .get()
    var ctx = try makeContext(cfg: cfg)
    ctx.award.insert(merge.iid)
    guard var state = try ctx.makeState(merge: merge) else { return false }
    state.original = fusion.original
    state.authors = try resolveAuthors(cfg: cfg, fusion: fusion)
    if fusion.autoApproveFork {
      for user in state.authors {
        state.approves[user] = .make(login: user, commit: head)
      }
    }
    state.skip = Set(pick.array)
    ctx.update(state: state)
    try storeContext(ctx: &ctx)
    return true
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
  func storeContext(ctx: inout Review.Context, skip: UInt? = nil) throws {
    let content = ctx.serialize(skip: skip)
    _ = try persistAsset(.init(
      cfg: ctx.cfg,
      asset: ctx.storage.asset,
      content: content,
      message: generate(ctx.cfg.createReviewStorageCommitMessage(
        storage: ctx.storage,
        generate: ctx.message
      ))
    ))
    let gitlab = try ctx.cfg.gitlab.get()
    for review in ctx.award { try gitlab
      .postMrAward(review: review, award: ctx.rules.hold)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    }
    ctx.reports.forEach(report)
    for review in ctx.trigger { try gitlab
      .postMrPipelines(review: review)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    }
  }
  func makeFusion(
    cfg: Configuration,
    review: Review,
    prefix: Review.Fusion.Prefix,
    target: String,
    source: String,
    fork: String
  ) throws -> Review.Fusion? {
    let fusion = try prefix.makeFusion(
      review: review,
      fork: .make(value: fork),
      target: .make(name: target),
      original: .make(name: source)
    )
    guard
      try Execute.parseSuccess(reply: execute(cfg.git.getSha(
        ref: .make(remote: fusion.source)
      ))).not,
      let fork = fusion.fork,
      try perform(cfg: cfg, check: .forkInTarget(fork: fork, target: fusion.target)).isEmpty
    else { return nil }
    return fusion
  }
  func checkApproves(
    ctx: Review.Context,
    state: inout Review.State,
    ownage: [String: Criteria]
  ) throws {
    guard let change = state.change, state.needApprovalCheck else { return }
    let head = Git.Ref.make(sha: change.head)
    let target = Git.Ref.make(remote: change.fusion.target)
    var fork = change.fusion.fork.map(Git.Ref.make(sha:))
    var childs: [Git.Sha: Set<Git.Sha>] = [:]
    for sha in try Execute.parseLines(reply: execute(ctx.cfg.git.listCommits(
      in: [head],
      notIn: [target] + fork.array,
      boundary: true
    ))) {
      let sha = try Git.Sha.make(value: sha)
      childs[sha] = try Execute
        .parseLines(reply: execute(ctx.cfg.git.listCommits(
          in: [head],
          notIn: [.make(sha: sha)]
        )))
        .map(Git.Sha.make(value:))
        .reduce(into: [], { $0.insert($1) })
    }
    guard change.fusion.propogation.not
    else { return state.update(ctx: ctx, childs: childs, diff: [], diffs: [:], ownage: ownage) }
    var diff: [String] = []
    var diffs: [Git.Sha: [String]] = [:]
    if change.fusion.duplication {
      fork = try .make(sha: .make(value: Execute.parseLines(reply: execute(ctx.cfg.git.listCommits(
        in: [head],
        notIn: [target]
      ))).end))
    }
    if let fork = fork {
      diff = try listMergeChanges(cfg: ctx.cfg, ref: head, parents: [target, fork])
    } else {
      diff = try Execute.parseLines(reply: execute(ctx.cfg.git.listChangedFiles(
        source: head,
        target: target
      )))
    }
    for sha in try Execute.parseLines(reply: execute(ctx.cfg.git.listCommits(
      in: [head],
      notIn: [target] + fork.array
    ))) {
      let sha = try Git.Sha.make(value: sha)
      diffs[sha] = try listChangedFiles(cfg: ctx.cfg, sha: sha)
    }
    state.update(ctx: ctx, childs: childs, diff: diff, diffs: diffs, ownage: ownage)
  }
  func perform(
    cfg: Configuration,
    check: Review.Fusion.GitCheck
  ) throws -> [Review.Problem] {
    var result: [Review.Problem] = []
    outer: switch check {
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
      guard
        let pick = try pickPoint(cfg: cfg, head: head, target: target),
        try isEqualTree(cfg: cfg, tree: pick, to: fork)
      else {
        result.append(.notCherry)
        break
      }
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
    case .forkNotProtected(let fork, let branches):
      if try branches.contains(where: { try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: $0),
        parent: .make(sha: fork)
      )))}).not { result.append(.forkNotProtected) }
    case .forkNotInSource(let fork, let head):
      if try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(sha: head),
        parent: .make(sha: fork)
      ))).not { result.append(.forkNotInSource) }
    case .forkParentNotInTarget(let fork, let target):
      if try Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: target),
        parent: .make(sha: fork).make(parent: 1)
      ))).not { result.append(.forkParentNotInTarget) }
    }
    return result
  }
  func pickPoint(
    cfg: Configuration,
    head: Git.Sha,
    target: Git.Branch
  ) throws -> Git.Sha? { try Execute
    .parseLines(reply: execute(cfg.git.listCommits(
      in: [.make(sha: head)],
      notIn: [.make(remote: target)]
    )))
    .last
    .map(Git.Sha.make(value:))
  }
  func isEqualTree(cfg: Configuration, tree one: Git.Sha, to two: Git.Sha) throws -> Bool {
    let one = try Execute
      .parseText(reply: execute(cfg.git.patchId(ref: .make(sha: one))))
      .dropSuffix(one.value)
    let two = try Execute
      .parseText(reply: execute(cfg.git.patchId(ref: .make(sha: two))))
      .dropSuffix(two.value)
    return one == two
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
  func checkReady(
    ctx: inout Review.Context,
    state: inout Review.State,
    merge: Json.GitlabMergeState
  ) throws -> Bool {
    let profile = try parseProfile(ctx.cfg.parseProfile(ref: .make(sha: .make(merge: merge))))
    let ownage = try ctx.cfg.parseCodeOwnage(profile: profile)
      .map(parseCodeOwnage)
      .get([:])
    guard
      try state.prepareChange(ctx: ctx, merge: merge),
      state.checkSanity(ctx: ctx, ownage: ownage, profile: profile)
    else {
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
    try checkApproves(ctx: ctx, state: &state, ownage: ownage)
    state.updatePhase()
    ctx.update(state: state)
    return state.phase == .ready
  }
  func checkActual(cfg: Configuration) throws -> Json.GitlabMergeState? {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.merge.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      report(cfg.report(notify: .pipelineOutdated, merge: merge))
      return nil
    }
    return merge
  }
  func prepareChange(
    ctx: inout Review.Context,
    merge: Json.GitlabMergeState
  ) throws -> Review.State? {
    guard ctx.isQueued(merge: merge).not else {
      report(ctx.cfg.report(notify: .reviewQueued, merge: merge))
      return nil
    }
    guard let state = try ctx.makeState(merge: merge) else {
      try storeContext(ctx: &ctx)
      return nil
    }
    return state
  }
  func storeChange(ctx: Review.Context, state: Review.State, merge: Json.GitlabMergeState) throws {
    var ctx = ctx
    var state = state
    guard
      try checkReady(ctx: &ctx, state: &state, merge: merge),
      try normalize(ctx: &ctx, state: &state)
    else { return try storeContext(ctx: &ctx, skip: state.review) }
    try storeContext(ctx: &ctx)
  }
  func normalize(
    ctx: inout Review.Context,
    state: inout Review.State
  ) throws -> Bool {
    guard let change = state.change else { return false }
    switch change.fusion {
    case .propose:
      guard try syncReview(ctx: &ctx, state: &state) else { return false }
    case .replicate(let replicate):
      guard try squashReview(ctx: &ctx, state: &state, fork: replicate.fork) else { return false }
    case .integrate(let integrate):
      guard try squashReview(ctx: &ctx, state: &state, fork: integrate.fork) else { return false }
    case .duplicate(let duplicate):
      guard
        let pick = try pickPoint(cfg: ctx.cfg, head: change.head, target: duplicate.target),
        try squashReview(ctx: &ctx, state: &state, fork: pick)
      else { return false }
    case .propogate: break
    }
    return ctx.isFirst(merge: change.merge)
  }
  func syncReview(
    ctx: inout Review.Context,
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
      state.shiftHead(to: sha)
    } else {
      state.add(problem: .conflicts)
    }
    ctx.update(state: state)
    return false
  }
  func squashPoint(
    cfg: Configuration,
    fusion: Review.Fusion,
    fork: Git.Sha,
    head: Git.Sha
  ) throws -> Git.Sha? {
    let fork = Git.Ref.make(sha: fork)
    let message = "Merge \(fusion.source.name) into \(fusion.target.name)"
    guard let head = try mergeReview(
      cfg: cfg,
      commit: .make(remote: fusion.target),
      into: .make(sha: head),
      message: message
    ) else { return nil }
    return try .make(value: Execute.parseText(reply: execute(cfg.git.commitTree(
      tree: .init(ref: .make(sha: head)),
      message: message,
      parents: [.make(remote: fusion.target), fork],
      env: Git.env(
        authorName: Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: fork))),
        authorEmail: Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: fork))),
        commiterName: Execute.parseText(reply: execute(cfg.git.getCommiterName(ref: fork))),
        commiterEmail: Execute.parseText(reply: execute(cfg.git.getCommiterEmail(ref: fork)))
      )
    ))))
  }
  func squashReview(
    ctx: inout Review.Context,
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
    guard let head = try squashPoint(
      cfg: ctx.cfg, fusion: change.fusion, fork: fork, head: change.head
    ) else {
      state.add(problem: .conflicts)
      ctx.update(state: state)
      return false
    }
    let gitlab = try ctx.cfg.gitlab.get()
    let rest = try gitlab.rest.get()
    try Execute.checkStatus(reply: execute(ctx.cfg.git.push(
      url: rest.push,
      branch: state.source,
      sha: head,
      force: true,
      secret: rest.secret
    )))
    state.shiftHead(to: head)
    state.squashApproves(to: head)
    ctx.update(state: state)
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
  func apply(
    cfg: Configuration,
    patch: Data,
    message: String,
    to ref: Git.Ref
  ) throws -> Git.Sha? { try perform(cfg: cfg, on: ref) {
    try Execute.checkStatus(reply: execute(cfg.git.apply(patch: patch)))
    return try? commitHead(cfg: cfg, as: ref, message: message, empty: false)
  }}
  func cherry(
    cfg: Configuration,
    sha: Git.Sha,
    to ref: Git.Ref
  ) throws -> Git.Sha? { try perform(cfg: cfg, on: ref) {
    let sha = Git.Ref.make(sha: sha)
    do {
      try Execute.checkStatus(reply: execute(cfg.git.cherry(ref: sha)))
    } catch {
      try Execute.checkStatus(reply: execute(cfg.git.quitCherry))
      return nil as Git.Sha?
    }
    return try? commitHead(
      cfg: cfg,
      as: sha,
      message: Execute.parseText(reply: execute(cfg.git.getCommitMessage(ref: sha))),
      empty: false
    )
  }}
  func mergeReview(
    cfg: Configuration,
    commit: Git.Ref,
    into first: Git.Ref,
    message: String
  ) throws -> Git.Sha? { try perform(cfg: cfg, on: first) {
    do { try Execute.checkStatus(reply: execute(cfg.git.merge(
      refs: [commit], message: nil, noFf: true, escalate: true
    ))) } catch {
      try Execute.checkStatus(reply: execute(cfg.git.quitMerge))
      return nil as Git.Sha?
    }
    return try commitHead(cfg: cfg, as: commit, message: message, empty: true)
  }}
  func perform<T>(cfg: Configuration, on ref: Git.Ref, action: Try.Do<T>) throws -> T {
    let head = try Execute.parseText(reply: execute(cfg.git.getSha(ref: .head)))
    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: ref)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    let result = Lossy.make(action)
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: .make(sha: .make(value: head)))))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    return try result.get()
  }
  func commitHead(
    cfg: Configuration,
    as ref: Git.Ref,
    message: String,
    empty: Bool
  ) throws -> Git.Sha {
    try Execute.checkStatus(reply: execute(cfg.git.addAll))
    try Execute.checkStatus(reply: execute(cfg.git.commit(
      message: message,
      allowEmpty: empty,
      env: Git.env(
        authorName: Execute
          .parseText(reply: execute(cfg.git.getAuthorName(ref: ref))),
        authorEmail: Execute
          .parseText(reply: execute(cfg.git.getAuthorEmail(ref: ref))),
        commiterName: Execute
          .parseText(reply: execute(cfg.git.getCommiterName(ref: ref))),
        commiterEmail: Execute
          .parseText(reply: execute(cfg.git.getCommiterEmail(ref: ref)))
      )
    )))
    return try .make(value: Execute.parseText(reply: execute(cfg.git.getSha(ref: .head))))
  }
  func acceptReview(
    ctx: inout Review.Context,
    state: Review.State
  ) throws -> Bool {
    guard let change = state.change else { throw MayDay("Unexpected merge state") }
    var params = Gitlab.PutMrMerge(
      squash: state.squash,
      shouldRemoveSourceBranch: true,
      sha: change.head
    )
    switch change.fusion {
    case .propose:
      params.squashCommitMessage = try generate(ctx.cfg.createMergeCommitMessage(
        merge: change.merge,
        review: ctx.review,
        fusion: change.fusion
      ))
    case .replicate, .integrate, .duplicate:
      params.mergeCommitMessage = try generate(ctx.cfg.createMergeCommitMessage(
        merge: change.merge,
        review: ctx.review,
        fusion: change.fusion
      ))
    case .propogate: break
    }
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
    guard let fork = state.change?.fusion.fork else { return }
    let queued = Set(ctx.storage.queues[state.target.name].get([]))
    let prefix = Review.Fusion.Prefix.replicate.prefix(target: state.target)
    for state in ctx.storage.states.values.filter({ queued.contains($0.review).not }) {
      guard
        let parent = try? Git.Sha.make(value: Execute.parseText(reply: execute(ctx.cfg.git.getSha(
          ref: .make(sha: .make(value: state.source.name.dropPrefix(prefix))).make(parent: 1)
        )))),
        try Execute.parseSuccess(reply: execute(ctx.cfg.git.check(
          child: .make(sha: fork),
          parent: .make(sha: parent)
        )))
      else { continue }
      ctx.trigger.insert(state.review)
    }
  }
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
  func resolveAuthors(
    cfg: Configuration,
    fusion: Review.Fusion
  ) throws -> Set<String> {
    let gitlab = try cfg.gitlab.get()
    guard let fork = fusion.fork else { return [] }
    let commits: [String]
    if fusion.duplication {
      commits = [fork.value]
    } else {
      commits = try Execute.parseLines(reply: execute(cfg.git.listCommits(
        in: [.make(sha: fork)],
        notIn: [.make(remote: fusion.target)],
        noMerges: true
      )))
    }
    var result: Set<String> = []
    for commit in commits { try gitlab
      .listShaMergeRequests(sha: .make(value: commit))
      .map(execute)
      .reduce([Json.GitlabCommitMergeRequest].self, jsonDecoder.decode(success:reply:))
      .get()
      .filter { $0.projectId == gitlab.job.pipeline.projectId }
      .filter { $0.squashCommitSha == commit }
      .forEach { result.insert($0.author.username) }
    }
    return result
  }
}
