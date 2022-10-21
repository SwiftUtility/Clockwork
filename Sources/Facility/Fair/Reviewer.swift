import Foundation
import Facility
import FacilityPure
public final class Reviewer {
  let execute: Try.Reply<Execute>
  let resolveFusion: Try.Reply<Configuration.ResolveFusion>
  let resolveFusionStatuses: Try.Reply<Configuration.ResolveFusionStatuses>
  let resolveReviewQueue: Try.Reply<Fusion.Queue.Resolve>
  let resolveApprovers: Try.Reply<Configuration.ResolveApprovers>
  let parseApprovalRules: Try.Reply<Configuration.ParseYamlSecret<Yaml.Fusion.Approval.Rules>>
  let parseCodeOwnage: Try.Reply<Configuration.ParseYamlFile<[String: Yaml.Criteria]>>
  let parseProfile: Try.Reply<Configuration.ParseYamlFile<Yaml.Profile>>
  let parseAntagonists: Try.Reply<Configuration.ParseYamlSecret<[String: Set<String>]>>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  let writeStdout: Act.Of<String>.Go
  let generate: Try.Reply<Generate>
  let report: Act.Reply<Report>
  let readStdin: Try.Reply<Configuration.ReadStdin>
  let createThread: Try.Reply<Report.CreateThread>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveFusion: @escaping Try.Reply<Configuration.ResolveFusion>,
    resolveFusionStatuses: @escaping Try.Reply<Configuration.ResolveFusionStatuses>,
    resolveReviewQueue: @escaping Try.Reply<Fusion.Queue.Resolve>,
    resolveApprovers: @escaping Try.Reply<Configuration.ResolveApprovers>,
    parseApprovalRules: @escaping Try.Reply<Configuration.ParseYamlSecret<Yaml.Fusion.Approval.Rules>>,
    parseCodeOwnage: @escaping Try.Reply<Configuration.ParseYamlFile<[String: Yaml.Criteria]>>,
    parseProfile: @escaping Try.Reply<Configuration.ParseYamlFile<Yaml.Profile>>,
    parseAntagonists: @escaping Try.Reply<Configuration.ParseYamlSecret<[String: Set<String>]>>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
    writeStdout: @escaping Act.Of<String>.Go,
    generate: @escaping Try.Reply<Generate>,
    report: @escaping Act.Reply<Report>,
    readStdin: @escaping Try.Reply<Configuration.ReadStdin>,
    createThread: @escaping Try.Reply<Report.CreateThread>,
    logMessage: @escaping Act.Reply<LogMessage>,
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
    self.readStdin = readStdin
    self.createThread = createThread
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func reportCustom(
    cfg: Configuration,
    event: String,
    stdin: Configuration.ReadStdin
  ) throws -> Bool {
    let stdin = try readStdin(stdin)
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try resolveReviewContext(cfg: cfg)
    let statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    guard let status = statuses[ctx.review.iid] else { throw Thrown("No review thread") }
    let approvers = try resolveApprovers(.init(cfg: cfg, approval: fusion.approval))
    report(cfg.reportReviewCustom(
      event: event,
      status: status,
      approvers: approvers,
      state: ctx.review,
      stdin: stdin
    ))
    return true
  }
  public func createReviewPipeline(
    cfg: Configuration
  ) throws -> Bool {
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    try ctx.gitlab.postMrPipelines(review: ctx.review.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func addReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    let labels = Set(labels).subtracting(.init(ctx.review.labels))
    guard !labels.isEmpty else {
      logMessage(.init(message: "No new labels"))
      return false
    }
    try ctx.gitlab
      .putMrState(
        parameters: .init(addLabels: labels.joined(separator: ",")),
        review: ctx.review.iid
      )
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    logMessage(.init(message: "Labels added"))
    return true
  }
  public func removeReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    let labels = Set(labels).intersection(.init(ctx.review.labels))
    guard !labels.isEmpty else {
      logMessage(.init(message: "Labels not present"))
      return false
    }
    try ctx.gitlab
      .putMrState(
        parameters: .init(removeLabels: labels.joined(separator: ",")),
        review: ctx.review.iid
      )
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    logMessage(.init(message: "Labels removed"))
    return true
  }
  public func cleanReviews(cfg: Configuration, remind: Bool) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let approvers = try resolveApprovers(.init(cfg: cfg, approval: fusion.approval))
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    let gitlabCi = try cfg.gitlabCi.get()
    for status in statuses.values {
      let state = try gitlabCi.getMrState(review: status.review)
        .map(execute)
        .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
        .get()
      guard state.state != "closed" else {
        report(cfg.reportReviewClosed(
          status: status,
          state: state,
          users: approvers,
          reason: .manual)
        )
        statuses[state.iid] = nil
        continue
      }
      guard state.state != "merged" else {
        statuses[state.iid] = nil
        continue
      }
      guard remind else { continue }
      let reminds = status.reminds(sha: state.lastPipeline.sha, approvers: approvers)
      guard reminds.isEmpty.not else { continue }
      report(cfg.reportReviewRemind(
        approvers: approvers,
        status: status,
        state: state,
        slackers: reminds
      ))
    }
    _ = try persist(statuses, cfg: cfg, fusion: fusion, state: nil, status: nil, reason: .clean)
    return true
  }
  public func updateApprover(
    cfg: Configuration,
    active: Bool,
    slack: String,
    gitlab: String
  ) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    var approvers = try resolveApprovers(.init(cfg: cfg, approval: fusion.approval))
    let user = try gitlab.isEmpty
      .else(gitlab)
      .get(cfg.gitlabCi.get().job.user.username)
    let slack = try slack.isEmpty
      .else(slack)
      .flatMapNil(approvers[user]?.slack)
      .get { throw Thrown("No slack id for user: \(user)") }
    let clones = approvers
      .filter({ $0.key != user && $0.value.slack == slack })
      .keys
      .joined(separator: ", ")
    guard clones.isEmpty else { throw Thrown("Same slack as: \(clones)") }
    approvers[user] = .make(login: user, active: active, slack: slack)
    return try persistAsset(.init(
      cfg: cfg,
      asset: fusion.approval.approvers,
      content: Fusion.Approval.Approver.yaml(approvers: approvers),
      message: generate(cfg.createApproversCommitMessage(
        fusion: fusion,
        user: user,
        active: active
      ))
    ))
  }
  public func skipReview(
    cfg: Configuration,
    review: UInt
  ) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let gitlabCi = try cfg.gitlabCi.get()
    let statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    let state = try gitlabCi.getMrState(review: review)
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    guard var status = statuses[review] else { return false }
    status.emergent = true
    return try persist(statuses, cfg: cfg, fusion: fusion, state: state, status: status, reason: .cheat)
  }
  public func approveReview(
    cfg: Configuration,
    resolution: Yaml.Fusion.Approval.Status.Resolution
  ) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    guard try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
      .isFirst(review: ctx.review.iid, target: ctx.review.targetBranch)
      .not
    else { return false }
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    var review = try resolveReview(cfg: cfg, state: ctx.review, fusion: fusion, statuses: &statuses)
    let wasApproved = review.isApproved(sha: ctx.review.lastPipeline.sha)
    try review.approve(job: ctx.job, resolution: resolution)
    guard try persist(statuses, cfg: cfg, fusion: fusion, state: ctx.review, status: review.status, reason: .approve)
    else { return false }
    if wasApproved.not, review.isApproved(sha: ctx.review.lastPipeline.sha) { try Execute.checkStatus(
      reply: execute(ctx.gitlab.postMrPipelines(review: ctx.review.iid).get())
    )}
    return true
  }
  public func dequeueReview(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
    return true
  }
  public func ownReview(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    guard try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
      .isFirst(review: ctx.review.iid, target: ctx.review.targetBranch)
      .not
    else { return false }
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    var review = try resolveReview(cfg: cfg, state: ctx.review, fusion: fusion, statuses: &statuses)
    try review.setAuthor(job: ctx.job)
    return try persist(statuses, cfg: cfg, fusion: fusion, state: ctx.review, status: review.status, reason: .own)
  }
  public func startReplication(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let gitlabCi = try cfg.gitlabCi.get()
    let project = try gitlabCi.getProject
      .map(execute)
      .reduce(Json.GitlabProject.self, jsonDecoder.decode(success:reply:))
      .get()
    let merge = try Fusion.Merge.make(
      fork: .make(value: gitlabCi.job.pipeline.sha),
      source: .init(name: gitlabCi.job.pipeline.ref),
      target: .init(name: project.defaultBranch),
      isReplication: true
    )
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
    let merge = try Fusion.Merge.make(
      fork: .make(value: fork),
      source: .init(name: source),
      target: .init(name: target),
      isReplication: false
    )
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
    let parent = try gitlabCi.env.parent.get()
    let job = try gitlabCi.getJob(id: parent.job)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let fusion = try resolveFusion(.init(cfg: cfg))
    let fork = try Git.Sha.make(job: job)
    let source = try Git.Branch.make(job: job)
    let targets = try resolveProtectedBranches(cfg: cfg)
      .filter({ try Execute.parseSuccess(
        reply: execute(cfg.git.mergeBase(.make(remote: $0), .make(sha: fork)))
      )})
      .filter({ try !Execute.parseSuccess(
        reply: execute(cfg.git.check(child: .make(remote: $0), parent: .make(sha: fork)))
      )})
    guard targets.isEmpty.not else {
      logMessage(.init(message: "No branches suitable for integration"))
      return false
    }
    try writeStdout(generate(cfg.exportIntegrationTargets(
      integration: fusion.integration,
      fork: fork,
      source: source.name,
      targets: targets.map(\.name)
    )))
    return true
  }
  public func updateReview(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    var review = try resolveReview(cfg: cfg, state: ctx.review, fusion: fusion, statuses: &statuses)
    guard try checkIsRebased(cfg: cfg, state: ctx.review) else {
      if let sha = try rebaseReview(cfg: cfg, state: ctx.review, fusion: fusion) {
        try Execute.checkStatus(reply: execute(cfg.git.push(
          url: ctx.gitlab.protected.get().push,
          branch: .init(name: ctx.review.sourceBranch),
          sha: sha,
          force: false
        )))
      } else {
        report(cfg.reportReviewMergeConflicts(review: review, state: ctx.review))
        try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
      }
      return false
    }
    if let reason = try checkClosers(
      cfg: cfg,
      state: ctx.review,
      gitlab: ctx.gitlab,
      kind: review.kind
    ) {
      try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
      try closeReview(cfg: cfg, state: ctx.review)
      _ = try persist(statuses, cfg: cfg, fusion: fusion, state: ctx.review, status: nil, reason: .close)
      report(cfg.reportReviewClosed(
        status: review.status,
        state: ctx.review,
        users: review.approvers,
        reason: reason
      ))
      return false
    }
    if let blockers = try checkReviewBlockers(cfg: cfg, state: ctx.review, review: review) {
      try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
      report(cfg.reportReviewBlocked(review: review, state: ctx.review, reasons: blockers))
      return false
    }
    let approval = try verify(cfg: cfg, state: ctx.review, fusion: fusion, review: &review)
    if approval.isUnapprovable {
      logMessage(.init(message: "Review is unapprovable"))
      report(cfg.reportReviewUnapprovable(
        review: review,
        state: ctx.review,
        approval: approval
      ))
      _ = try persist(statuses, cfg: cfg, fusion: fusion, state: ctx.review, status: review.status, reason: .update)
      return false
    }
    report(cfg.reportReviewUpdate(review: review, state: ctx.review, update: approval))
    guard approval.state.isApproved else {
      logMessage(.init(message: "Review is unapproved"))
      try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
      _ = try persist(statuses, cfg: cfg, fusion: fusion, state: ctx.review, status: review.status, reason: .update)
      return false
    }
    guard try checkIsSquashed(cfg: cfg, state: ctx.review, kind: review.kind) else {
      let sha = try squashReview(cfg: cfg, state: ctx.review, fusion: fusion, kind: review.kind)
      try Execute.checkStatus(reply: execute(cfg.git.push(
        url: ctx.gitlab.protected.get().push,
        branch: .init(name: ctx.review.sourceBranch),
        sha: sha,
        force: true
      )))
      logMessage(.init(message: "Updating approves commits"))
      review.squashApproves(sha: sha)
      _ = try persist(statuses, cfg: cfg, fusion: fusion, state: ctx.review, status: review.status, reason: .update)
      return false
    }
    _ = try persist(statuses, cfg: cfg, fusion: fusion, state: ctx.review, status: review.status, reason: .update)
    return try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: true)
  }
  public func acceptReview(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    let queue = try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
    guard queue.isFirst(review: ctx.review.iid, target: ctx.review.targetBranch)
    else { return false }
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    var review = try resolveReview(cfg: cfg, state: ctx.review, fusion: fusion, statuses: &statuses)
    review.prepareVerification(source: ctx.review.sourceBranch, target: ctx.review.targetBranch)
    guard
      try checkIsRebased(cfg: cfg, state: ctx.review),
      try checkIsSquashed(cfg: cfg, state: ctx.review, kind: review.kind),
      try checkClosers(cfg: cfg, state: ctx.review, gitlab: ctx.gitlab, kind: review.kind) == nil,
      try checkReviewBlockers(cfg: cfg, state: ctx.review, review: review) == nil,
      review.isApproved(sha: ctx.review.lastPipeline.sha)
    else {
      try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
      logMessage(.init(message: "Bad last pipeline state"))
      return false
    }
    try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
    switch review.kind {
    case .proposition:
      guard try acceptReview(
        cfg: cfg,
        state: ctx.review,
        review: review,
        message: generate(cfg.createPropositionCommitMessage(
          proposition: fusion.proposition,
          review: ctx.review
        ))
      ) else { return false }
    case .replication(let merge):
      guard try acceptReview(
        cfg: cfg,
        state: ctx.review,
        review: review,
        message: generate(cfg.createReplicationCommitMessage(
          replication: fusion.replication,
          merge: merge
        ))
      ) else { return false }
      if let merge = try shiftReplication(cfg: cfg, merge: merge) { try createReview(
        cfg: cfg,
        gitlab: ctx.gitlab,
        merge: merge,
        title: generate(cfg.createReplicationCommitMessage(
          replication: fusion.replication,
          merge: merge
        ))
      )}
    case .integration(let merge):
      guard try acceptReview(
        cfg: cfg,
        state: ctx.review,
        review: review,
        message: generate(cfg.createIntegrationCommitMessage(
          integration: fusion.integration,
          merge: merge
        ))
      ) else { return false }
    }
    _ = try persist(statuses, cfg: cfg, fusion: fusion, state: ctx.review, status: nil, reason: .merge)
    return true
  }
  func resolveStatus(
    cfg: Configuration,
    approvers: [String: Fusion.Approval.Approver],
    state: Json.GitlabReviewState,
    fusion: Fusion,
    kind: Fusion.Kind,
    statuses: inout [UInt: Fusion.Approval.Status]
  ) throws -> Fusion.Approval.Status {
    if let status = statuses[state.iid] { return status }
    let authors = try resolveAuthors(cfg: cfg, state: state, kind: kind)
    let thread = try createThread(cfg.reportReviewCreated(
      fusion: fusion,
      review: state,
      users: approvers,
      authors: authors
    ))
    let status = Fusion.Approval.Status.make(
      review: state.iid,
      target: state.targetBranch,
      authors: authors,
      thread: .make(yaml: thread),
      fork: nil
    )
    _ = try persist(statuses, cfg: cfg, fusion: fusion, state: state, status: status, reason: .create)
    return status
  }
  func resolveOwnage(
    cfg: Configuration,
    state: Json.GitlabReviewState
  ) throws -> [String: Criteria] { try cfg.gitlabCi
      .flatMap(\.env.parent)
      .map(\.profile)
      .reduce(.make(sha: .make(value: state.lastPipeline.sha)), Git.File.init(ref:path:))
      .map { file in try Configuration.Profile.make(
        profile: file,
        yaml: parseProfile(.init(git: cfg.git, file: file))
      )}
      .map(\.codeOwnage)
      .get()
      .reduce(cfg.git, Configuration.ParseYamlFile<[String: Yaml.Criteria]>.init(git:file:))
      .map(parseCodeOwnage)
      .get([:])
      .mapValues(Criteria.init(yaml:))
  }
  func resolveReview(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    fusion: Fusion,
    statuses: inout [UInt: Fusion.Approval.Status]
  ) throws -> Review {
    logMessage(.init(message: "Loading status assets"))
    let kind = try fusion.makeKind(supply: state.sourceBranch)
    let approvers = try resolveApprovers(.init(cfg: cfg, approval: fusion.approval))
    var result = try Review.make(
      bot: cfg.gitlabCi.get().protected.get().user.username,
      status: resolveStatus(
        cfg: cfg,
        approvers: approvers,
        state: state,
        fusion: fusion,
        kind: kind,
        statuses: &statuses
      ),
      approvers: approvers,
      review: state,
      kind: kind,
      ownage: resolveOwnage(cfg: cfg, state: state),
      rules: resolveRules(cfg: cfg, fusion: fusion),
      haters: fusion.approval.haters
        .reduce(cfg, Configuration.ParseYamlSecret.init(cfg:secret:))
        .map(parseAntagonists)
        .get([:])
    )
    result.prepareVerification(source: state.sourceBranch, target: state.targetBranch)
    return result
  }
  func resolveRules(cfg: Configuration, fusion: Fusion) throws -> Fusion.Approval.Rules {
    try .make(yaml: parseApprovalRules(.init(cfg: cfg, secret: fusion.approval.rules)))
  }
  func verify(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    fusion: Fusion,
    review: inout Review
  ) throws -> Review.Approval {
    logMessage(.init(message: "Validating approves"))
    let fork = review.kind.merge
      .map(\.fork)
      .map(Git.Ref.make(sha:))
    let current = try Git.Sha.make(value: state.lastPipeline.sha)
    let target = try Git.Ref.make(remote: .init(name: state.targetBranch))
    if let fork = review.kind.merge?.fork {
      try review.prepareVerification(diff: listMergeChanges(
        cfg: cfg,
        ref: .make(sha: current),
        parents: [target, .make(sha: fork)]
      ))
    } else {
      try review.prepareVerification(diff: Execute.parseLines(
        reply: execute(cfg.git.listChangedFiles(
          source: .make(sha: current),
          target: target
        ))
      ))
    }
    for sha in try Execute.parseLines(reply: execute(cfg.git.listCommits(
      in: [.make(sha: current)],
      notIn: [target] + fork.array
    ))) {
      let sha = try Git.Sha.make(value: sha)
      try review.addChanges(sha: sha, diff: listChangedFiles(cfg: cfg, state: state, sha: sha))
    }
    for sha in review.status.approvedCommits { try review.addBreakers(
      sha: sha,
      commits: Execute
        .parseLines(reply: execute(cfg.git.listCommits(
          in: [.make(sha: current)],
          notIn: [target, .make(sha: sha)] + fork.array,
          ignoreMissing: true
        )))
        .map(Git.Sha.make(value:))
    )}
    return review.performVerification(sha: current)
  }
  func checkClosers(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    gitlab: GitlabCi,
    kind: Fusion.Kind
  ) throws -> Report.ReviewClosed.Reason? {
    logMessage(.init(message: "Checking should close review"))
    switch kind {
    case .proposition(let rule):
      guard rule != nil else { return .noSourceRule }
    case .replication(let merge):
      guard try state.author.username == gitlab.protected.get().user.username
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
      let target = try resolveBranch(cfg: cfg, name: merge.target.name)
      guard target.protected else { return .targetNotProtected }
      guard target.default else { return .targetNotDefault }
      let source = try resolveBranch(cfg: cfg, name: merge.source.name)
      guard source.protected else { return .sourceNotProtected }
    case .integration(let merge):
      guard try state.author.username == gitlab.protected.get().user.username
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
      let target = try resolveBranch(cfg: cfg, name: merge.target.name)
      guard target.protected else { return .targetNotProtected }
      let source = try resolveBranch(cfg: cfg, name: merge.source.name)
      guard source.protected else { return .sourceNotProtected }
    }
    return nil
  }
  func checkReviewBlockers(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    review: Review
  ) throws -> [Report.ReviewBlocked.Reason]? {
    logMessage(.init(message: "Checking blocking reasons"))
    var result: [Report.ReviewBlocked.Reason] = []
    if state.draft { result.append(.draft) }
    if state.workInProgress { result.append(.workInProgress) }
    if !state.blockingDiscussionsResolved { result.append(.blockingDiscussions) }
    if
      let sanity = review.rules.sanity,
      !cfg.profile.checkSanity(criteria: review.ownage[sanity])
    { result.append(.sanity) }
    if review.unknownUsers.isEmpty.not { result.append(.unknownUsers) }
    if review.unknownTeams.isEmpty.not { result.append(.unknownTeams) }
    let excludes: [Git.Ref]
    switch review.kind {
    case .proposition(let rule):
      if !state.squash { result.append(.squashStatus) }
      let target = try resolveBranch(cfg: cfg, name: state.targetBranch)
      if !target.protected { result.append(.badTarget) }
      guard let rule = rule else { throw MayDay("no proposition rule") }
      if !rule.title.isMet(state.title) { result.append(.badTitle) }
      if let task = rule.task {
        let source = try findMatches(in: state.sourceBranch, regexp: task)
        let title = try findMatches(in: state.title, regexp: task)
        if source.symmetricDifference(title).isEmpty { result.append(.taskMismatch) }
      }
      try excludes = [.make(remote: .init(name: state.targetBranch))]
    case .replication(let merge), .integration(let merge):
      if state.squash { result.append(.squashStatus) }
      if state.targetBranch != merge.target.name { result.append(.badTarget) }
      excludes = [.make(remote: merge.target), .make(sha: merge.fork)]
    }
    let head = try Git.Sha.make(value: state.lastPipeline.sha)
    for branch in try resolveProtectedBranches(cfg: cfg) {
      guard let base = try? Execute.parseText(reply: execute(cfg.git.mergeBase(
        .make(remote: branch),
        .make(sha: head)
      ))) else { continue }
      let extras = try Execute.parseLines(reply: execute(cfg.git.listCommits(
        in: [.make(sha: .make(value: base))],
        notIn: excludes
      )))
      guard !extras.isEmpty else { continue }
      result.append(.extraCommits)
      break
    }
    return result.isEmpty.else(result)
  }
  func checkIsRebased(
    cfg: Configuration,
    state: Json.GitlabReviewState
  ) throws -> Bool {
    logMessage(.init(message: "Checking fast forward state"))
    return try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(sha: .make(value: state.lastPipeline.sha)),
      parent: .make(remote: .init(name: state.targetBranch))
    )))
  }
  func checkIsSquashed(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    kind: Fusion.Kind
  ) throws -> Bool {
    logMessage(.init(message: "Checking squash required"))
    guard let fork = kind.merge?.fork else { return true }
    let parents = try Id(state.lastPipeline.sha)
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
      .map(cfg.git.listParents(ref:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .map(Git.Sha.make(value:))
    let target = try Id(state.targetBranch)
      .map(Git.Branch.init(name:))
      .map(Git.Ref.make(remote:))
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.make(value:))
      .get()
    return parents == [fork, target]
  }
  func listChangedFiles(
    cfg: Configuration,
    state: Json.GitlabReviewState,
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
  @discardableResult
  func changeQueue(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    fusion: Fusion,
    enqueue: Bool
  ) throws -> Bool {
    if enqueue { logMessage(.init(message: "Enqueueing review")) }
    else { logMessage(.init(message: "Dequeueing review")) }
    let gitlab = try cfg.gitlabCi.get()
    var queue = try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
    let notifiables = queue.enqueue(
      review: state.iid,
      target: enqueue.then(state.targetBranch)
    )
    let message = try generate(cfg.createReviewQueueCommitMessage(
      fusion: fusion,
      review: state,
      queued: enqueue
    ))
    _ = try persistAsset(.init(
      cfg: cfg,
      asset: fusion.queue,
      content: queue.yaml,
      message: message
    ))
    for notifiable in notifiables {
      try Execute.checkStatus(reply: execute(gitlab.postMrPipelines(review: notifiable).get()))
    }
    return queue.isFirst(review: state.iid, target: state.targetBranch)
  }
  func rebaseReview(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    fusion: Fusion
  ) throws -> Git.Sha? {
    logMessage(.init(message: "Merging target into source"))
    let initial = try Id(.head)
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let sha = try Git.Ref.make(sha: .make(value: state.lastPipeline.sha))
    let message = try generate(cfg.createFusionMergeCommitMessage(
      fusion: fusion,
      review: state
    ))
    let name = try Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: sha)))
    let email = try Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: sha)))
    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: sha)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    do {
      try Execute.checkStatus(reply: execute(cfg.git.merge(
        refs: [.make(remote: .init(name: state.targetBranch))],
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
      .map(Git.Sha.make(value:))
      .get()
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: initial)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    return result
  }
  func squashReview(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    fusion: Fusion,
    kind: Fusion.Kind
  ) throws -> Git.Sha {
    logMessage(.init(message: "Squashing source commits"))
    guard let merge = kind.merge else { throw MayDay("Squashing proposition") }
    let fork = Git.Ref.make(sha: merge.fork)
    let name = try Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: fork)))
    let email = try Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: fork)))
    return try Git.Sha.make(value: Execute.parseText(reply: execute(cfg.git.commitTree(
      tree: .init(ref: .make(sha: .make(value: state.lastPipeline.sha))),
      message: generate(cfg.createFusionMergeCommitMessage(
        fusion: fusion,
        review: state
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
  func closeReview(cfg: Configuration, state: Json.GitlabReviewState) throws {
    logMessage(.init(message: "Closing gitlab review"))
    let gitlab = try cfg.gitlabCi.get()
    try gitlab
      .putMrState(parameters: .init(stateEvent: "close"), review: state.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try Id
      .make(cfg.git.push(
        url: gitlab.protected.get().push,
        delete: .init(name: state.sourceBranch)
      ))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  func acceptReview(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    review: Review,
    message: String
  ) throws -> Bool {
    let result = try cfg.gitlabCi.get()
      .putMrMerge(
        parameters: .init(
          mergeCommitMessage: message,
          squashCommitMessage: message,
          squash: state.squash,
          shouldRemoveSourceBranch: true,
          sha: .make(value: state.lastPipeline.sha)
        ),
        review: state.iid
      )
      .map(execute)
      .map(\.data)
      .get()
      .reduce(AnyCodable.self, jsonDecoder.decode(_:from:))
    if case "merged"? = result?.map?["state"]?.value?.string {
      logMessage(.init(message: "Review merged"))
      report(cfg.reportReviewMerged(review: review, state: state))
      return true
    } else if let message = result?.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      report(cfg.reportReviewMergeError(review: review, state: state, error: message))
      return false
    } else {
      throw MayDay("Unexpected merge response")
    }
  }
  func shiftReplication(
    cfg: Configuration,
    merge: Fusion.Merge
  ) throws -> Fusion.Merge? {
    let fork = try Id
      .make(cfg.git.listCommits(
        in: [.make(remote: merge.source)],
        notIn: [.make(sha: merge.fork)],
        firstParents: true
      ))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .last
      .map(Git.Sha.make(value:))
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
  func persist(
    _ statuses: [UInt: Fusion.Approval.Status],
    cfg: Configuration,
    fusion: Fusion,
    state: Json.GitlabReviewState?,
    status: Fusion.Approval.Status?,
    reason: Generate.CreateFusionStatusesCommitMessage.Reason
  ) throws -> Bool {
    logMessage(.init(message: "Persisting review status"))
    var statuses = statuses
    if let state = state { statuses[state.iid] = status }
    return try persistAsset(.init(
      cfg: cfg,
      asset: fusion.approval.statuses,
      content: Fusion.Approval.Status.yaml(statuses: statuses),
      message: generate(cfg.createFusionStatusesCommitMessage(
        fusion: fusion,
        review: state,
        reason: reason
      ))
    ))
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
  func resolveBranch(cfg: Configuration, name: String) throws -> Json.GitlabBranch { try cfg
      .gitlabCi
      .flatReduce(curry: name, GitlabCi.getBranch(name:))
      .map(execute)
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(success:reply:))
      .get()
  }
  func resolveProtectedBranches(cfg: Configuration) throws -> [Git.Branch] {
    var result: [Git.Branch] = []
    var page = 1
    let gitlab = try cfg.gitlabCi.get()
    while true {
      let branches = try gitlab
        .getBranches(page: page, count: 100)
        .map(execute)
        .reduce([Json.GitlabBranch].self, jsonDecoder.decode(success:reply:))
        .get()
      result += try branches
        .filter(\.protected)
        .map(\.name)
        .map(Git.Branch.init(name:))
      guard branches.count == 100 else { return result }
      page += 1
    }
  }
  func resolveAuthors(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    kind: Fusion.Kind
  ) throws -> Set<String> {
    let gitlab = try cfg.gitlabCi.get()
    guard let merge = kind.merge else { return [state.author.username] }
    let bot = try cfg.gitlabCi.get().protected.get().user.username
    let commits = try Execute.parseLines(reply: execute(cfg.git.listCommits(
      in: [.make(sha: merge.fork)],
      notIn: [.make(remote: merge.target)],
      noMerges: true
    )))
    var result: Set<String> = []
    for commit in commits { try gitlab
        .listShaMergeRequests(sha: .make(value: commit))
        .map(execute)
        .reduce([Json.GitlabCommitMergeRequest].self, jsonDecoder.decode(success:reply:))
        .get()
        .filter { $0.projectId == gitlab.job.pipeline.projectId }
        .filter { $0.squashCommitSha == commit }
        .filter { $0.author.username != bot }
        .forEach { result.insert($0.author.username) }
    }
    return result
  }
  func resolveReviewContext(cfg: Configuration) throws -> Review.Context {
    logMessage(.init(message: "Loading gitlab review"))
    let gitlabCi = try cfg.gitlabCi.get()
    let parent = try gitlabCi.env.parent.get()
    let job = try gitlabCi.getJob(id: parent.job)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let review = try job.review
      .flatMap(gitlabCi.getMrState(review:))
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    if job.pipeline.id != review.lastPipeline.id {
      logMessage(.init(message: "Pipeline outdated"))
    }
    if review.state != "opened" {
      logMessage(.init(message: "Review state: \(review.state)"))
    }
    return .make(
      gitlab: gitlabCi,
      job: job,
      profile: parent.profile,
      review: review,
      isLastPipe: job.pipeline.id == review.lastPipeline.id
    )
  }
}
