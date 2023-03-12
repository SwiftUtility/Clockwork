//import Foundation
//import Facility
//import FacilityPure
//public final class Reviewer {
//  let execute: Try.Reply<Execute>
//  let parseReview: Try.Reply<ParseYamlFile<Review>>
//  let parseReviewStorage: Try.Reply<ParseYamlFile<Review.Storage>>
//  let parseReviewRules: Try.Reply<ParseYamlSecret<Review.Rules>>
//  let parseCodeOwnage: Try.Reply<ParseYamlFile<[String: Criteria]>>
//  let parseProfile: Try.Reply<ParseYamlFile<Configuration.Profile>>
//  let parseStdin: Try.Reply<Configuration.ParseStdin>
//  let persistAsset: Try.Reply<Configuration.PersistAsset>
//  let writeStdout: Act.Of<String>.Go
//  let generate: Try.Reply<Generate>
//  let readStdin: Try.Do<Data?>
//  let logMessage: Act.Reply<LogMessage>
//  let jsonDecoder: JSONDecoder
//  public init(
//    execute: @escaping Try.Reply<Execute>,
//    parseReview: @escaping Try.Reply<ParseYamlFile<Review>>,
//    parseReviewStorage: @escaping Try.Reply<ParseYamlFile<Review.Storage>>,
//    parseReviewRules: @escaping Try.Reply<ParseYamlSecret<Review.Rules>>,
//    parseCodeOwnage: @escaping Try.Reply<ParseYamlFile<[String: Criteria]>>,
//    parseProfile: @escaping Try.Reply<ParseYamlFile<Configuration.Profile>>,
//    parseStdin: @escaping Try.Reply<Configuration.ParseStdin>,
//    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
//    writeStdout: @escaping Act.Of<String>.Go,
//    generate: @escaping Try.Reply<Generate>,
//    readStdin: @escaping Try.Do<Data?>,
//    logMessage: @escaping Act.Reply<LogMessage>,
//    jsonDecoder: JSONDecoder
//  ) {
//    self.execute = execute
//    self.parseReview = parseReview
//    self.parseReviewStorage = parseReviewStorage
//    self.parseReviewRules = parseReviewRules
//    self.parseCodeOwnage = parseCodeOwnage
//    self.parseProfile = parseProfile
//    self.parseStdin = parseStdin
//    self.persistAsset = persistAsset
//    self.writeStdout = writeStdout
//    self.generate = generate
//    self.readStdin = readStdin
//    self.logMessage = logMessage
//    self.jsonDecoder = jsonDecoder
//  }
//  public func resolveState(query: Review.State.Resolve) throws -> Review.State.Resolve.Reply {
//    var ctx = try makeContext(cfg: query.cfg)
//    let state = try ctx.makeState(merge: query.merge).get(.make(merge: query.merge, bots: ctx.bots))
//    try storeContext(ctx: &ctx)
//    return state
//  }
//  public func updateReviews(cfg: Configuration) throws -> Bool {
//    var ctx = try makeContext(cfg: cfg)
//    var checked: Set<UInt> = []
//    for iid in ctx.storage.queues.values.compactMap(\.first) {
//      checked.insert(iid)
//      guard let merge = try getMerge(ctx: &ctx, iid: iid) else { continue }
//      if merge.lastPipeline.isFailed { ctx.dequeue(merge: merge) }
//    }
//    for state in ctx.storage.states.values {
//      guard
//        checked.contains(state.review).not,
//        let merge = try getMerge(ctx: &ctx, iid: state.review),
//        var state = try ctx.makeState(merge: merge)
//      else { continue }
//      guard
//        try state.prepareChange(ctx: ctx, merge: merge),
//        let phase = state.phase,
//        phase != .block
//      else {
//        ctx.trigger.insert(state.review)
//        continue
//      }
//      try state.update(
//        ctx: ctx,
//        merge: merge,
//        awards: resolveAwards(cfg: ctx.cfg, review: state.review),
//        discussions: []
//      )
//      if phase == .stuck, state.problems.get([]).isEmpty {
//        ctx.trigger.insert(state.review)
//      }
//      if phase != .stuck, state.problems.get([]).isEmpty.not {
//        ctx.trigger.insert(state.review)
//      }
//    }
//    try storeContext(ctx: &ctx)
//    return true
//  }
//  public func patchReview(
////    cfg: Configuration,
////    subject: Contract.Subject<Contract.ReviewPatch>
//  ) throws -> Bool {
//    #warning("TBD")
//    return false
////    let gitlab = try cfg.gitlab.get()
////    var ctx = try makeContext(cfg: cfg)
////    let merge = try gitlab
////      .getMrState(review: subject.contract.job)
////      .map(execute)
////      .reduce(Json.GitlabMergeState.self, jsonDecoder.decode(success:reply:))
////      .get()
////    let branch = try Git.Branch.make(name: merge.sourceBranch)
////    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
////    let message = try generate(ctx.cfg.createPatchCommitMessage(merge: merge, review: ctx.review))
////    guard subject.contract.job == merge.lastPipeline.sha else {
////      ctx.cfg.reportReviewFail(merge: merge, state: state, reason: .pipelineOutdated)
////      return false
////    }
////    guard
////      subject.payload.patch.isEmpty.not,
////      let sha = try apply(
////        cfg: cfg,
////        patch: subject.payload.patch,
////        message: message,
////        to: .make(sha: .make(merge: merge))
////      )
////    else {
////      ctx.cfg.reportReviewFail(merge: merge, state: state, reason: .patchFailed)
////      return false
////    }
////    try Execute.checkStatus(reply: execute(cfg.git.push(
////      gitlab: gitlab, branch: branch, sha: sha, force: false
////    )))
////    if subject.payload.skip { state.skip.insert(sha) }
////    ctx.update(state: state)
////    try storeContext(ctx: &ctx, skip: state.review)
////    return true
//  }
//  public func skipReview(
//    cfg: Configuration,
//    iid: UInt
//  ) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    var ctx = try makeContext(cfg: cfg)
//    guard let merge = try getMerge(ctx: &ctx, iid: iid) else { return false }
//    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
//    let sha = try Git.Sha.make(merge: merge)
//    state.emergent = sha
//    state.authors.insert(gitlab.job.user.username)
//    try storeChange(ctx: &ctx, state: &state, merge: merge)
//    return true
//  }
//  public func approveReview(cfg: Configuration, advance: Bool) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    var ctx = try makeContext(cfg: cfg)
//    guard let merge = try getMerge(ctx: &ctx, iid: nil) else { return false }
//    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
//    try state.approve(job: gitlab.parent.get(), advance: advance)
//    try storeChange(ctx: &ctx, state: &state, merge: merge)
//    return true
//  }
//  public func dequeueReview(cfg: Configuration, iid: UInt) throws -> Bool {
//    var ctx = try makeContext(cfg: cfg)
//    guard let merge = try getMerge(ctx: &ctx, iid: (iid > 0).then(iid), latest: true)
//    else { return false }
//    ctx.dequeue(merge: merge)
//    try storeContext(ctx: &ctx, skip: merge.iid)
//    return true
//  }
//  public func ownReview(cfg: Configuration, user: String, iid: UInt) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    var ctx = try makeContext(cfg: cfg)
//    guard let merge = try getMerge(ctx: &ctx, iid: (iid > 0).then(iid)) else { return false }
//    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
//    let user = user.isEmpty.not.then(user).get(gitlab.job.user.username)
//    state.authors.insert(user)
//    try storeChange(ctx: &ctx, state: &state, merge: merge)
//    return true
//  }
//  public func unownReview(cfg: Configuration, user: String, iid: UInt) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    var ctx = try makeContext(cfg: cfg)
//    guard let merge = try getMerge(ctx: &ctx, iid: (iid > 0).then(iid)) else { return false }
//    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
//    let user = user.isEmpty.not.then(user).get(gitlab.job.user.username)
//    state.authors.remove(user)
//    try storeChange(ctx: &ctx, state: &state, merge: merge)
//    return true
//  }
//  public func remindReview(cfg: Configuration, iid: UInt) throws -> Bool {
//    let iid = try (iid > 0).then(iid).get(cfg.gitlab.flatMap(\.parent).flatMap(\.review).get())
//    var ctx = try makeContext(cfg: cfg)
//    guard let merge = try getMerge(ctx: &ctx, iid: (iid > 0).then(iid)) else { return false }
//    guard let state = ctx.storage.states[iid] else { return false }
//    for user in state.approvers.filter(state.isUnapproved(user:)) {
//      cfg.reportReviewApprove(user: user, merge: merge, state: state, reason: .remind)
//    }
//    try storeContext(ctx: &ctx)
//    return true
//  }
//  public func listReviews(cfg: Configuration, user: String) throws -> Bool {
//    var ctx = try makeContext(cfg: cfg)
//    let users = user.isEmpty.then(ctx.approvers).get([user])
//    var reviews: [UInt: [String: Report.ReviewApprove]] = [:]
//    for state in ctx.storage.states.values {
//      guard state.verified != nil else { continue }
//      let users = state.approvers.intersection(users).filter(state.isUnapproved(user:))
//      guard users.isEmpty.not else { continue }
//      guard let merge = try getMerge(ctx: &ctx, iid: state.review) else { continue }
//      reviews[state.review] = users
//        .map({ .make(merge: merge, state: state, user: $0) })
//        .indexed(\.user)
//    }
//    for user in users {
//      let reviews = reviews.values
//        .compactMap({ $0[user] })
//        .sorted(\.review.iid)
//      guard reviews.isEmpty.not || users.count == 1 else { continue }
//      cfg.reportReviewList(user: user, reviews: reviews)
//    }
//    try storeContext(ctx: &ctx)
//    return true
//  }
//  public func startFusion(
//    cfg: Configuration,
//    prefix: Review.Fusion.Prefix,
//    source: String,
//    target: String,
//    fork: String
//  ) throws -> Bool {
//    let review = try cfg.parseReview.map(parseReview).get()
//    guard let fusion = try makeFusion(
//      cfg: cfg, review: review, prefix: prefix, target: target, source: source, fork: fork
//    ) else { return true }
//    var head = try Git.Sha.make(value: fork)
//    var pick: Git.Sha? = nil
//    if prefix == .duplicate {
//      guard let commit = try cherry(cfg: cfg, sha: head, to: .make(remote: fusion.target)) else {
//        cfg.reportFusionFail(source: source, target: target, fork: fork, reason: .duplicate)
//        return false
//      }
//      pick = commit
//      head = commit
//    } else if prefix == .propogate {
//      guard try Execute.parseSuccess(reply: execute(cfg.git.check(
//        child: .make(sha: head),
//        parent: .make(remote: fusion.target)
//      ))) else {
//        cfg.reportFusionFail(source: source, target: target, fork: fork, reason: .propogate)
//        return false
//      }
//    }
//    return try createReview(cfg: cfg, review: review, fusion: fusion, head: head, pick: pick)
//  }
//  public func renderTargets(
//    cfg: Configuration,
//    stdin: Configuration.ParseStdin,
//    args: [String]
//  ) throws -> Bool {
//    let stdin = try parseStdin(stdin)
//    let gitlab = try cfg.gitlab.get()
//    let parent = try gitlab.parent.get()
//    let review = try cfg.parseReview.map(parseReview).get()
//    let fork = try Git.Sha.make(job: parent)
//    let ref = Git.Ref.make(sha: fork)
//    let source = try Git.Branch.make(job: parent)
//    let targets = try resolveBranches(cfg: cfg).reduce(into: [String: Bool](), { result, target in
//      let remote = try Git.Ref.make(remote: .make(name: target.name))
//      guard
//        target.protected,
//        result[target.name] == nil,
//        try Execute.parseSuccess(reply: execute(cfg.git.mergeBase(remote, ref))),
//        try !Execute.parseSuccess(reply: execute(cfg.git.check(child: remote, parent: ref)))
//      else { return }
//      result[target.name] = try Execute.parseSuccess(reply: execute(cfg.git.check(
//        child: ref,
//        parent: remote
//      )))
//    })
//    let integrate = targets.keys.map(\.alphaNumeric).sorted().map(\.value)
//    let duplicate = try Execute.parseLines(reply: execute(cfg.git.listParents(ref: ref))).count == 1
//    try writeStdout(generate(cfg.exportTargets(
//      review: review,
//      fork: fork,
//      source: source.name,
//      integrate: integrate,
//      duplicate: duplicate.then(integrate).get([]),
//      propogate: integrate.filter({ targets[$0] == true }),
//      stdin: stdin,
//      args: args
//    )))
//    return true
//  }
//  public func rebaseReview(cfg: Configuration, iid: UInt) throws -> Bool {
//    var ctx = try makeContext(cfg: cfg)
//    guard let merge = try getMerge(ctx: &ctx, iid: (iid > 0).then(iid)) else { return false }
//    guard var state = try prepareChange(ctx: &ctx, merge: merge) else { return false }
//    _ = try checkReady(ctx: &ctx, state: &state, merge: merge)
//    guard let change = state.change, let fusion = change.fusion, state.canRebase else {
//      ctx.cfg.reportReviewFail(merge: merge, state: state, reason: .rebaseBlocked)
//      return false
//    }
//    var head = Git.Ref.make(sha: change.head)
//    let target = Git.Ref.make(remote: fusion.target)
//    var commit = try Git.Sha.make(value: Execute.parseText(reply: execute(cfg.git.mergeBase(
//      target,
//      head
//    ))))
//    for sha in try Execute.parseLines(reply: execute(cfg.git.listCommits(
//      in: [target],
//      notIn: [head]
//    ))) {
//      let sha = try Git.Sha.make(value: sha)
//      guard let merge = try mergeReview(
//        cfg: cfg,
//        commit: .make(sha: sha),
//        into: head,
//        message: "Temp"
//      ) else { continue }
//      head = .make(sha: merge)
//      commit = sha
//      break
//    }
//    for sha in try Execute
//      .parseLines(reply: execute(cfg.git.listCommits(in: [head], notIn: [target])))
//      .map(Git.Sha.make(value:))
//      .reversed()
//    {
//      let skip = state.skip.remove(sha) != nil
//      if let pick = try cherry(cfg: cfg, sha: sha, to: .make(sha: commit)) {
//        if skip { state.skip.insert(pick) }
//        commit = pick
//      }
//      state.approves.keys.forEach({ state.approves[$0]?.shift(sha: sha, to: commit) })
//    }
//    if try isEqualTree(cfg: cfg, tree: commit, to: change.head).not {
//      commit = try .make(value: Execute.parseText(reply: execute(cfg.git.commitTree(
//        tree: .init(ref: head),
//        message: "Squash unpickable commits",
//        parents: [.make(sha: commit)],
//        env: [:]
//      ))))
//      state.skip.insert(commit)
//    }
//    state.shiftHead(to: commit)
//    ctx.update(state: state)
//    let gitlab = try cfg.gitlab.get()
//    try Execute.checkStatus(reply: execute(ctx.cfg.git.push(
//      gitlab: gitlab,
//      branch: fusion.source,
//      sha: commit,
//      force: true
//    )))
//    try storeContext(ctx: &ctx, skip: iid)
//    return true
//  }
//  public func enqueueReview(cfg: Configuration) throws -> Bool {
//    var ctx = try makeContext(cfg: cfg)
//    guard let merge = try getMerge(ctx: &ctx, iid: nil, latest: true) else { return false }
//    guard
//      var state = try ctx.makeState(merge: merge),
//      try checkReady(ctx: &ctx, state: &state, merge: merge),
//      try normalize(ctx: &ctx, state: &state)
//    else {
//      try storeContext(ctx: &ctx, skip: merge.iid)
//      return false
//    }
//    try storeContext(ctx: &ctx, skip: merge.iid)
//    return true
//  }
//  public func acceptReview(cfg: Configuration) throws -> Bool {
//    var ctx = try makeContext(cfg: cfg)
//    guard let merge = try getMerge(ctx: &ctx, iid: nil, latest: true) else { return true }
//    if ctx.isFirst(merge: merge).not {
//      ctx.trigger.insert(merge.iid)
//    } else if
//      var state = try ctx.makeState(merge: merge),
//      try checkReady(ctx: &ctx, state: &state, merge: merge),
//      try normalize(ctx: &ctx, state: &state),
//      try acceptReview(ctx: &ctx, state: state)
//    {
//      try helpReviews(ctx: &ctx, state: state)
//    }
//    try storeContext(ctx: &ctx)
//    return true
//  }
//}
//extension Reviewer {
//  func getMerge(
//    ctx: inout Review.Context,
//    iid: UInt?,
//    latest: Bool = false
//  ) throws -> Json.GitlabMerge? {
//    let gitlab = try ctx.cfg.gitlab.get()
//    if let iid = iid { return try gitlab
//      .getMrState(review: iid)
//      .map(execute)
//      .reduce(Json.GitlabMerge.self, jsonDecoder.decode(success:reply:))
//      .get()
//    } else {
//      let parent = try gitlab.parent.get()
//      let merge = try gitlab.merge.get()
//      if latest {
//        guard parent.pipeline.id == merge.lastPipeline.id else {
//          if let state = try ctx.makeState(merge: merge) {
//            ctx.cfg.reportReviewFail(merge: merge, state: state, reason: .pipelineOutdated)
//          } else {
//            try storeContext(ctx: &ctx)
//          }
//          return nil
//        }
//      } else {
//        guard parent.pipeline.sha == merge.lastPipeline.sha else {
//          if let state = try ctx.makeState(merge: merge) {
//            ctx.cfg.reportReviewFail(merge: merge, state: state, reason: .pipelineOutdated)
//          } else {
//            try storeContext(ctx: &ctx)
//          }
//          return nil
//        }
//      }
//      return merge
//    }
//  }
//  func createReview(
//    cfg: Configuration,
//    review: Review,
//    fusion: Review.Fusion,
//    head: Git.Sha,
//    pick: Git.Sha? = nil
//  ) throws -> Bool {
//    let gitlab = try cfg.gitlab.get()
//    let title = try generate(cfg.createMergeTitle(review: review, fusion: fusion))
//    var ctx = try makeContext(cfg: cfg)
//    try Execute.checkStatus(reply: execute(cfg.git.push(
//      gitlab: gitlab, branch: fusion.source, sha: head, force: false
//    )))
//    let merge = try gitlab
//      .postMergeRequests(parameters: .init(
//        sourceBranch: fusion.source.name, targetBranch: fusion.target.name, title: title
//      ))
//      .map(execute)
//      .map(Execute.parseData(reply:))
//      .reduce(Json.GitlabMerge.self, jsonDecoder.decode(_:from:))
//      .get()
//    ctx.award.insert(merge.iid)
//    guard var state = try ctx.makeState(merge: merge) else { return false }
//    state.original = fusion.original
//    state.authors = try resolveAuthors(cfg: cfg, fusion: fusion)
//      .subtracting(ctx.bots)
//    if fusion.autoApproveFork {
//      for user in state.authors {
//        state.approves[user] = .make(login: user, commit: head)
//      }
//    }
//    let author = gitlab.job.user.username
//    if ctx.bots.contains(author).not { state.authors.insert(author) }
//    state.skip.formUnion(pick.array)
//    ctx.update(state: state)
//    try storeContext(ctx: &ctx)
//    return true
//  }
//  func storeContext(ctx: inout Review.Context, skip: UInt? = nil) throws {
//    let content = ctx.serialize(skip: skip)
//    _ = try persistAsset(.init(
//      cfg: ctx.cfg,
//      asset: ctx.storage.review.storage,
//      content: content,
//      message: generate(ctx.cfg.createReviewStorageCommitMessage(
//        review: ctx.storage.review,
//        context: ctx.message
//      ))
//    ))
//    let gitlab = try ctx.cfg.gitlab.get()
//    for review in ctx.award { try gitlab
//      .postMrAward(review: review, award: ctx.rules.hold)
//      .map(execute)
//      .map(Execute.checkStatus(reply:))
//      .get()
//    }
//    for review in ctx.trigger { try gitlab
//      .postMrPipelines(review: review)
//      .map(execute)
//      .map(Execute.checkStatus(reply:))
//      .get()
//    }
//  }
//  func makeFusion(
//    cfg: Configuration,
//    review: Review,
//    prefix: Review.Fusion.Prefix,
//    target: String,
//    source: String,
//    fork: String
//  ) throws -> Review.Fusion? {
//    let fusion = try prefix.makeFusion(
//      review: review,
//      fork: .make(value: fork),
//      target: .make(name: target),
//      original: .make(name: source)
//    )
//    guard
//      try Execute.parseSuccess(reply: execute(cfg.git.getSha(
//        ref: .make(remote: fusion.source)
//      ))).not,
//      let fork = fusion.fork,
//      try perform(cfg: cfg, check: .forkInTarget(fork: fork, target: fusion.target)).isEmpty
//    else { return nil }
//    return fusion
//  }
//  func checkApproves(
//    ctx: Review.Context,
//    state: inout Review.State,
//    ownage: [String: Criteria]
//  ) throws {
//    guard let change = state.change, let fusion = change.fusion, state.needApprovalCheck else { return }
//    let head = Git.Ref.make(sha: change.head)
//    let target = Git.Ref.make(remote: fusion.target)
//    var fork = fusion.fork.map(Git.Ref.make(sha:))
//    var childs: [Git.Sha: Set<Git.Sha>] = [:]
//    if fusion.propogation, let fork = fusion.fork { return state.update(
//      ctx: ctx,
//      childs: [fork: []],
//      diff: [],
//      diffs: [:],
//      ownage: ownage
//    )}
//    if
//      fusion.duplication,
//      let pick = try pickPoint(cfg: ctx.cfg, head: change.head, target: fusion.target)
//    {
//      fork = .make(sha: pick)
//      childs[pick] = []
//    } else if let fork = fusion.fork {
//      childs[fork] = []
//    }
//    var diff: [String] = []
//    var diffs: [Git.Sha: [String]] = [:]
//    if let fork = fork {
//      let base = try Git.Ref.make(sha: .make(value: Execute.parseText(
//        reply: execute(ctx.cfg.git.mergeBase(target, head))
//      )))
//      diff = try listMergeChanges(cfg: ctx.cfg, ref: head, parents: [base, fork])
//    } else {
//      diff = try Execute.parseLines(reply: execute(ctx.cfg.git.listChangedFiles(
//        source: head,
//        target: target
//      )))
//    }
//    for sha in try Execute.parseLines(reply: execute(ctx.cfg.git.listCommits(
//      in: [head],
//      notIn: [target] + fork.array
//    ))) {
//      let sha = try Git.Sha.make(value: sha)
//      diffs[sha] = try listChangedFiles(cfg: ctx.cfg, sha: sha)
//      childs[sha] = try Execute
//        .parseLines(reply: execute(ctx.cfg.git.listCommits(
//          in: [head],
//          notIn: [target, .make(sha: sha)] + fork.array
//        )))
//        .map(Git.Sha.make(value:))
//        .reduce(into: [], { $0.insert($1) })
//    }
//    state.update(ctx: ctx, childs: childs, diff: diff, diffs: diffs, ownage: ownage)
//  }
//  func perform(
//    cfg: Configuration,
//    check: Review.Fusion.GitCheck
//  ) throws -> [Review.Problem] {
//    var result: [Review.Problem] = []
//    outer: switch check {
//    case .extraCommits(let branches, let exclude, let head):
//      var extras: Set<Git.Branch> = []
//      for branch in branches {
//        guard let base = try? Execute.parseText(reply: execute(cfg.git.mergeBase(
//          .make(remote: branch),
//          .make(sha: head)
//        ))) else { continue }
//        guard try Execute.parseLines(reply: execute(cfg.git.listCommits(
//          in: [.make(sha: .make(value: base))],
//          notIn: exclude
//        ))).isEmpty.not else { continue }
//        extras.insert(branch)
//      }
//      if extras.isEmpty.not { result.append(.extraCommits(extras)) }
//    case .notCherry(let fork, let head, let target):
//      guard
//        let pick = try pickPoint(cfg: cfg, head: head, target: target),
//        try isCherryPick(cfg: cfg, one: pick, two: fork)
//      else {
//        result.append(.notCherry)
//        break
//      }
//    case .notForward(let fork, let head, let target):
//      if fork != head { result.append(.sourceNotAtFrok) }
//      if try Execute.parseSuccess(reply: execute(cfg.git.check(
//        child: .make(sha: fork),
//        parent: .make(remote: target)
//      ))).not { result.append(.notForward) }
//    case .forkInTarget(let fork, let target):
//      if try Execute.parseSuccess(reply: execute(cfg.git.check(
//        child: .make(remote: target),
//        parent: .make(sha: fork)
//      ))) { result.append(.forkInTarget) }
//    case .forkNotProtected(let fork, let branches):
//      if try branches.contains(where: { try Execute.parseSuccess(reply: execute(cfg.git.check(
//        child: .make(remote: $0),
//        parent: .make(sha: fork)
//      )))}).not { result.append(.forkNotProtected) }
//    case .forkNotInSource(let fork, let head):
//      if try Execute.parseSuccess(reply: execute(cfg.git.check(
//        child: .make(sha: head),
//        parent: .make(sha: fork)
//      ))).not { result.append(.forkNotInSource) }
//    case .forkParentNotInTarget(let fork, let target):
//      if try Execute.parseSuccess(reply: execute(cfg.git.check(
//        child: .make(remote: target),
//        parent: .make(sha: fork).make(parent: 1)
//      ))).not { result.append(.forkParentNotInTarget) }
//    #warning("Configuration & sanity check")
//    }
//    return result
//  }
//  func pickPoint(
//    cfg: Configuration,
//    head: Git.Sha,
//    target: Git.Branch
//  ) throws -> Git.Sha? { try Execute
//    .parseLines(reply: execute(cfg.git.listCommits(
//      in: [.make(sha: head)],
//      notIn: [.make(remote: target)]
//    )))
//    .last
//    .map(Git.Sha.make(value:))
//  }
//  func isEqualTree(cfg: Configuration, tree one: Git.Sha, to two: Git.Sha) throws -> Bool {
//    let tree1 = try Execute.parseText(reply: execute(cfg.git.getTree(ref: .make(sha: one))))
//    let tree2 = try Execute.parseText(reply: execute(cfg.git.getTree(ref: .make(sha: two))))
//    return tree1 == tree2
//  }
//  func isCherryPick(cfg: Configuration, one: Git.Sha, two: Git.Sha) throws -> Bool {
//    guard
//      let patch1 = try? Execute
//        .parseText(reply: execute(cfg.git.patchId(ref: .make(sha: one))))
//        .dropSuffix(one.value),
//      let patch2 = try? Execute
//        .parseText(reply: execute(cfg.git.patchId(ref: .make(sha: two))))
//        .dropSuffix(two.value),
//      patch1 == patch2
//    else { return false }
//    let checks = [
//      cfg.git.getCommitMessage(ref:),
//      cfg.git.getAuthorName(ref:),
//      cfg.git.getAuthorEmail(ref:),
//      cfg.git.getCommiterName(ref:),
//      cfg.git.getCommiterEmail(ref:),
//    ]
//    let shas = [one, two].map(Git.Ref.make(sha:))
//    for check in checks {
//      let results = try shas.map(check).map(execute).map(Execute.parseText(reply:))
//      guard results.first == results.last else { return false }
//    }
//    return true
//  }
//  func makeContext(cfg: Configuration) throws -> Review.Context {
//    let review = try cfg.parseReview.map(parseReview).get()
//    return try .make(
//      cfg: cfg,
//      review: review,
//      rules: parseReviewRules(cfg.parseReviewRules(review: review)),
//      storage: parseReviewStorage(cfg.parseReviewStorage(review: review))
//    )
//  }
//  func checkReady(
//    ctx: inout Review.Context,
//    state: inout Review.State,
//    merge: Json.GitlabMerge
//  ) throws -> Bool {
//    let profile = try parseProfile(ctx.cfg.parseProfile(ref: .make(sha: .make(merge: merge))))
//    let ownage = try ctx.cfg.parseCodeOwnage(profile: profile)
//      .map(parseCodeOwnage)
//      .get([:])
//    guard
//      try state.prepareChange(ctx: ctx, merge: merge),
//      state.checkSanity(ctx: ctx, ownage: ownage, profile: profile)
//    else {
//      ctx.update(state: state)
//      return false
//    }
//    try state
//      .makeGitCheck(branches: resolveBranches(cfg: ctx.cfg))
//      .flatMap({ try perform(cfg: ctx.cfg, check: $0) })
//      .forEach({ state.add(problem: $0) })
//    try state.update(
//      ctx: ctx,
//      merge: merge,
//      awards: resolveAwards(cfg: ctx.cfg, review: state.review),
//      discussions: resolveDiscussions(cfg: ctx.cfg, review: state.review)
//    )
//    try checkApproves(ctx: ctx, state: &state, ownage: ownage)
//    state.updatePhase()
//    ctx.update(state: state)
//    return state.phase == .ready
//  }
//  func prepareChange(
//    ctx: inout Review.Context,
//    merge: Json.GitlabMerge
//  ) throws -> Review.State? {
//    guard let state = try ctx.makeState(merge: merge) else {
//      try storeContext(ctx: &ctx)
//      return nil
//    }
//    guard ctx.isQueued(merge: merge).not else {
//      ctx.cfg.reportReviewFail(merge: merge, state: state, reason: .reviewQueued)
//      return nil
//    }
//    return state
//  }
//  func storeChange(ctx: inout Review.Context, state: inout Review.State, merge: Json.GitlabMerge) throws {
//    guard
//      try checkReady(ctx: &ctx, state: &state, merge: merge),
//      try normalize(ctx: &ctx, state: &state)
//    else { return try storeContext(ctx: &ctx, skip: state.review) }
//    try storeContext(ctx: &ctx)
//  }
//  func normalize(
//    ctx: inout Review.Context,
//    state: inout Review.State
//  ) throws -> Bool {
//    guard let change = state.change, let fusion = change.fusion else { return false }
//    switch fusion {
//    case .propose:
//      guard try syncReview(ctx: &ctx, state: &state) else { return false }
//    case .replicate(let replicate):
//      guard try squashReview(ctx: &ctx, state: &state, fork: replicate.fork) else { return false }
//    case .integrate(let integrate):
//      guard try squashReview(ctx: &ctx, state: &state, fork: integrate.fork) else { return false }
//    case .duplicate(let duplicate):
//      guard
//        let pick = try pickPoint(cfg: ctx.cfg, head: change.head, target: duplicate.target),
//        try squashReview(ctx: &ctx, state: &state, fork: pick)
//      else { return false }
//    case .propogate: break
//    }
//    return ctx.isFirst(merge: change.merge)
//  }
//  func syncReview(
//    ctx: inout Review.Context,
//    state: inout Review.State
//  ) throws -> Bool {
//    guard let change = state.change, let fusion = change.fusion else { return false }
//    guard try Execute.parseSuccess(reply: execute(ctx.cfg.git.check(
//      child: .make(sha: change.head),
//      parent: .make(remote: fusion.target)
//    ))).not else { return true }
//    if let sha = try mergeReview(
//      cfg: ctx.cfg,
//      commit: .make(remote: fusion.target),
//      into: .make(sha: change.head),
//      message: "Merge \(fusion.target.name) into \(fusion.source.name)"
//    ) {
//      let gitlab = try ctx.cfg.gitlab.get()
//      try Execute.checkStatus(reply: execute(ctx.cfg.git.push(
//        gitlab: gitlab, branch: state.source, sha: sha, force: false
//      )))
//      state.shiftHead(to: sha)
//    } else {
//      state.add(problem: .conflicts)
//    }
//    ctx.update(state: state)
//    return false
//  }
//  func squashPoint(
//    cfg: Configuration,
//    fusion: Review.Fusion,
//    fork: Git.Sha,
//    head: Git.Sha,
//    message: String
//  ) throws -> Git.Sha? {
//    let fork = Git.Ref.make(sha: fork)
//    guard let head = try mergeReview(
//      cfg: cfg,
//      commit: .make(remote: fusion.target),
//      into: .make(sha: head),
//      message: message
//    ) else { return nil }
//    return try .make(value: Execute.parseText(reply: execute(cfg.git.commitTree(
//      tree: .init(ref: .make(sha: head)),
//      message: message,
//      parents: [.make(remote: fusion.target), fork],
//      env: Git.env(
//        authorName: Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: fork))),
//        authorEmail: Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: fork))),
//        commiterName: Execute.parseText(reply: execute(cfg.git.getCommiterName(ref: fork))),
//        commiterEmail: Execute.parseText(reply: execute(cfg.git.getCommiterEmail(ref: fork)))
//      )
//    ))))
//  }
//  func squashReview(
//    ctx: inout Review.Context,
//    state: inout Review.State,
//    fork: Git.Sha
//  ) throws -> Bool {
//    guard
//      let change = state.change,
//      let fusion = change.fusion,
//      let message = try ctx.cfg
//        .createMergeCommitMessage(merge: change.merge, review: ctx.review, fusion: fusion)
//        .map(generate)
//    else { return false }
//    let target = try Git.Sha.make(value: Execute.parseText(reply: execute(ctx.cfg.git.getSha(
//      ref: .make(remote: state.target)
//    ))))
//    let parents = try Execute.parseLines(reply: execute(ctx.cfg.git.listParents(
//      ref: .make(sha: change.head)
//    )))
//    let checks = [
//      ctx.cfg.git.getAuthorName(ref:),
//      ctx.cfg.git.getAuthorEmail(ref:),
//      ctx.cfg.git.getCommiterName(ref:),
//      ctx.cfg.git.getCommiterEmail(ref:),
//    ]
//    let forkInfo = try checks
//      .map({ try Execute.parseText(reply: execute($0(.make(sha: fork)))) })
//    let headInfo = try checks
//      .map({ try Execute.parseText(reply: execute($0(.make(sha: change.head)))) })
//    let headMessage = try Execute
//      .parseText(reply: execute(ctx.cfg.git.getCommitMessage(ref: .make(sha: change.head))))
//    guard message != headMessage || forkInfo != headInfo || parents != [target.value, fork.value]
//    else { return true }
//    guard let head = try squashPoint(
//      cfg: ctx.cfg, fusion: fusion, fork: fork, head: change.head, message: message
//    ) else {
//      state.add(problem: .conflicts)
//      ctx.update(state: state)
//      return false
//    }
//    let gitlab = try ctx.cfg.gitlab.get()
//    try Execute.checkStatus(reply: execute(ctx.cfg.git.push(
//      gitlab: gitlab, branch: state.source, sha: head, force: true
//    )))
//    state.shiftHead(to: head)
//    state.squashApproves(to: head)
//    ctx.update(state: state)
//    return false
//  }
//  func listChangedFiles(
//    cfg: Configuration,
//    sha: Git.Sha
//  ) throws -> [String] {
//    let sha = Git.Ref.make(sha: sha)
//    let parents = try Execute.parseLines(reply: execute(cfg.git.listParents(ref: sha)))
//    if parents.count > 1 {
//      return try listMergeChanges(
//        cfg: cfg,
//        ref: sha,
//        parents: parents
//          .map(Git.Sha.make(value:))
//          .map(Git.Ref.make(sha:))
//      )
//    } else {
//      return try Execute.parseLines(reply: execute(cfg.git.listChangedFiles(
//        source: sha,
//        target: sha.make(parent: 1)
//      )))
//    }
//  }
//  func listMergeChanges(
//    cfg: Configuration,
//    ref: Git.Ref,
//    parents: [Git.Ref]
//  ) throws -> [String] {
//    guard parents.count > 1 else { throw MayDay("not a merge") }
//    let initial = try Execute.parseText(reply: execute(cfg.git.getSha(ref: .head)))
//    try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: parents[0])))
//    try Execute.checkStatus(reply: execute(cfg.git.clean))
//    try Execute.checkStatus(reply: execute(cfg.git.merge(
//      refs: .init(parents[1..<parents.endIndex]),
//      message: nil,
//      noFf: true,
//      escalate: false
//    )))
//    try Execute.checkStatus(reply: execute(cfg.git.quitMerge))
//    try Execute.checkStatus(reply: execute(cfg.git.addAll))
//    try Execute.checkStatus(reply: execute(cfg.git.resetSoft(ref: ref)))
//    let result = try Execute.parseLines(reply: execute(cfg.git.listLocalChanges))
//    try Execute.checkStatus(reply: execute(cfg.git.resetHard(
//      ref: .make(sha: .make(value: initial))
//    )))
//    try Execute.checkStatus(reply: execute(cfg.git.clean))
//    return result
//  }
//  func apply(
//    cfg: Configuration,
//    patch: Data,
//    message: String,
//    to ref: Git.Ref
//  ) throws -> Git.Sha? { try perform(cfg: cfg, on: ref) {
//    try Execute.checkStatus(reply: execute(cfg.git.apply(patch: patch)))
//    return try? commitHead(cfg: cfg, as: ref, message: message, empty: false)
//  }}
//  func cherry(
//    cfg: Configuration,
//    sha: Git.Sha,
//    to ref: Git.Ref
//  ) throws -> Git.Sha? { try perform(cfg: cfg, on: ref) {
//    let sha = Git.Ref.make(sha: sha)
//    do {
//      try Execute.checkStatus(reply: execute(cfg.git.cherry(ref: sha)))
//    } catch {
//      try Execute.checkStatus(reply: execute(cfg.git.quitCherry))
//      return nil as Git.Sha?
//    }
//    return try? commitHead(
//      cfg: cfg,
//      as: sha,
//      message: Execute.parseText(reply: execute(cfg.git.getCommitMessage(ref: sha))),
//      empty: false
//    )
//  }}
//  func mergeReview(
//    cfg: Configuration,
//    commit: Git.Ref,
//    into first: Git.Ref,
//    message: String
//  ) throws -> Git.Sha? { try perform(cfg: cfg, on: first) {
//    do { try Execute.checkStatus(reply: execute(cfg.git.merge(
//      refs: [commit], message: nil, noFf: true, escalate: true
//    ))) } catch {
//      try Execute.checkStatus(reply: execute(cfg.git.quitMerge))
//      return nil as Git.Sha?
//    }
//    return try commitHead(cfg: cfg, as: commit, message: message, empty: true)
//  }}
//  func perform<T>(cfg: Configuration, on ref: Git.Ref, action: Try.Do<T>) throws -> T {
//    let head = try Execute.parseText(reply: execute(cfg.git.getSha(ref: .head)))
//    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: ref)))
//    try Execute.checkStatus(reply: execute(cfg.git.clean))
//    let result = Lossy.make(action)
//    try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: .make(sha: .make(value: head)))))
//    try Execute.checkStatus(reply: execute(cfg.git.clean))
//    return try result.get()
//  }
//  func commitHead(
//    cfg: Configuration,
//    as ref: Git.Ref,
//    message: String,
//    empty: Bool
//  ) throws -> Git.Sha {
//    try Execute.checkStatus(reply: execute(cfg.git.addAll))
//    try Execute.checkStatus(reply: execute(cfg.git.commit(
//      message: message,
//      allowEmpty: empty,
//      env: Git.env(
//        authorName: Execute
//          .parseText(reply: execute(cfg.git.getAuthorName(ref: ref))),
//        authorEmail: Execute
//          .parseText(reply: execute(cfg.git.getAuthorEmail(ref: ref))),
//        commiterName: Execute
//          .parseText(reply: execute(cfg.git.getCommiterName(ref: ref))),
//        commiterEmail: Execute
//          .parseText(reply: execute(cfg.git.getCommiterEmail(ref: ref)))
//      )
//    )))
//    return try .make(value: Execute.parseText(reply: execute(cfg.git.getSha(ref: .head))))
//  }
//  func acceptReview(
//    ctx: inout Review.Context,
//    state: Review.State
//  ) throws -> Bool {
//    guard let change = state.change, let fusion = change.fusion
//    else { throw MayDay("Unexpected merge state") }
//    let gitlab = try ctx.cfg.gitlab.get()
//    let result = try gitlab
//      .putMrMerge(
//        parameters: .init(
//          squashCommitMessage: ctx.cfg
//            .createSquashCommitMessage(
//              merge: change.merge,
//              review: ctx.review,
//              fusion: fusion
//            )
//            .map(generate),
//          squash: state.squash,
//          shouldRemoveSourceBranch: true,
//          sha: change.head
//        ),
//        review: state.review
//      )
//      .map(execute)
//      .map(\.data)
//      .get()
//      .reduce(AnyCodable.self, jsonDecoder.decode(_:from:))
//    if case "merged"? = result?.map?["state"]?.value?.string {
//      ctx.merge(merge: change.merge)
//      return true
//    } else if let message = result?.map?["message"]?.value?.string {
//      ctx.cfg.reportReviewMergeError(state: state, merge: change.merge, error: message)
//      ctx.dequeue(merge: change.merge)
//      return false
//    } else {
//      ctx.dequeue(merge: change.merge)
//      return false
//    }
//  }
//  func helpReviews(ctx: inout Review.Context, state: Review.State) throws {
//    guard let change = state.change, let fusion = change.fusion else { return }
//    guard let fork = fusion.fork else { return }
//    guard fusion.duplication.not else { return }
//    let queued = Set(ctx.storage.queues[state.target.name].get([]))
//    let prefix = Review.Fusion.Prefix.replicate.prefix(target: state.target)
//    for state in ctx.storage.states.values.filter({ queued.contains($0.review).not }) {
//      guard
//        let parent = try? Git.Sha.make(value: Execute.parseText(reply: execute(ctx.cfg.git.getSha(
//          ref: .make(sha: .make(value: state.source.name.dropPrefix(prefix))).make(parent: 1)
//        )))),
//        try Execute.parseSuccess(reply: execute(ctx.cfg.git.check(
//          child: .make(sha: fork),
//          parent: .make(sha: parent)
//        )))
//      else { continue }
//      ctx.trigger.insert(state.review)
//    }
//  }
//  func resolveBranches(cfg: Configuration) throws -> [Json.GitlabBranch] {
//    var result: [Json.GitlabBranch] = []
//    var page = 1
//    let gitlab = try cfg.gitlab.get()
//    while true {
//      let branches = try gitlab
//        .getBranches(page: page, count: 100)
//        .map(execute)
//        .reduce([Json.GitlabBranch].self, jsonDecoder.decode(success:reply:))
//        .get()
//      result += branches
//      guard branches.count == 100 else { return result }
//      page += 1
//    }
//  }
//  func resolveAwards(cfg: Configuration, review: UInt) throws -> [Json.GitlabAward] {
//    var result: [Json.GitlabAward] = []
//    var page = 1
//    let gitlab = try cfg.gitlab.get()
//    while true {
//      let awarders = try gitlab.getMrAwarders(review: review, page: page, count: 100)
//        .map(execute)
//        .reduce([Json.GitlabAward].self, jsonDecoder.decode(success:reply:))
//        .get()
//      result += awarders
//      guard awarders.count == 100 else { return result }
//      page += 1
//    }
//  }
//  func resolveDiscussions(cfg: Configuration, review: UInt) throws -> [Json.GitlabDiscussion] {
//    var result: [Json.GitlabDiscussion] = []
//    var page = 1
//    let gitlab = try cfg.gitlab.get()
//    while true {
//      let discussions = try gitlab.getMrDiscussions(review: review, page: page, count: 100)
//        .map(execute)
//        .reduce([Json.GitlabDiscussion].self, jsonDecoder.decode(success:reply:))
//        .get()
//      result += discussions
//      guard discussions.count == 100 else { return result }
//      page += 1
//    }
//  }
//  func resolveAuthors(
//    cfg: Configuration,
//    fusion: Review.Fusion
//  ) throws -> Set<String> {
//    let gitlab = try cfg.gitlab.get()
//    guard let fork = fusion.fork else { return [] }
//    let commits: [String]
//    if fusion.duplication {
//      commits = [fork.value]
//    } else {
//      commits = try Execute.parseLines(reply: execute(cfg.git.listCommits(
//        in: [.make(sha: fork)],
//        notIn: [.make(remote: fusion.target)],
//        noMerges: true
//      )))
//    }
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
//    return result.subtracting([gitlab.job.user.username])
//  }
//}
