import Foundation
import Facility
import FacilityPure
public final class Reviewer {
  let execute: Try.Reply<Execute>
  let resolveFusion: Try.Reply<Configuration.ResolveFusion>
  let resolveFusionStatuses: Try.Reply<Configuration.ResolveFusionStatuses>
  let resolveReviewQueue: Try.Reply<Fusion.Queue.Resolve>
  let parseApprovers: Try.Reply<Configuration.ParseYamlFile<[String: Yaml.Review.Approval.Approver]>>
  let parseApprovalRules: Try.Reply<Configuration.ParseYamlFile<Yaml.Review.Approval.Rules>>
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
    parseApprovers: @escaping Try.Reply<Configuration.ParseYamlFile<[String: Yaml.Review.Approval.Approver]>>,
    parseApprovalRules: @escaping Try.Reply<Configuration.ParseYamlFile<Yaml.Review.Approval.Rules>>,
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
    self.parseApprovers = parseApprovers
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
    let approvers = try resolveApprovers(cfg: cfg, fusion: fusion)
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    let status = try resolveStatus(
      cfg: cfg,
      approvers: approvers,
      state: ctx.review,
      fusion: fusion,
      kind: fusion.makeKind(state: ctx.review, project: ctx.project),
      statuses: &statuses
    )
    report(cfg.reportReviewThread(
      event: event,
      status: status,
      approvers: approvers,
      state: ctx.review,
      stdin: stdin
    ))
    return true
  }
  public func createReviewPipeline(cfg: Configuration) throws -> Bool {
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    try cfg.gitlabCi
      .flatReduce(curry: ctx.review.iid, GitlabCi.postMrPipelines(review:))
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
    let approvers = try resolveApprovers(cfg: cfg, fusion: fusion)
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    let gitlabCi = try cfg.gitlabCi.get()
    for status in statuses.values {
      let state = try gitlabCi.getMrState(review: status.review)
        .map(execute)
        .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
        .get()
      guard state.state != "closed" else {
        report(cfg.reportReviewClosed(status: status, state: state, users: approvers))
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
    gitlab: String,
    command: Fusion.Approval.Approver.Command
  ) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let rules = try resolveRules(cfg: cfg, fusion: fusion)
    var approvers = try resolveApprovers(cfg: cfg, fusion: fusion)
    let user = try gitlab.isEmpty
      .else(gitlab)
      .get(cfg.gitlabCi.get().job.user.username)
    if case .register(let slack) = command {
      guard approvers[user] == nil else { throw Thrown("Already exists \(user)") }
      approvers[user] = .make(login: user, active: true, slack: slack)
    } else {
      guard var approver = approvers[user] else { throw Thrown("No approver \(user)") }
      switch command {
      case .register: break
      case .activate: approver.active = true
      case .deactivate: approver.active = false
      case .unwatchAuthors(let authors):
        let unknown = authors.filter({ approver.watchAuthors.contains($0).not })
        guard unknown.isEmpty
        else { throw Thrown("Not watching authors: \(unknown.joined(separator: ", "))") }
        approver.watchAuthors = approver.watchAuthors.subtracting(authors)
      case .unwatchTeams(let teams):
        let unknown = teams.filter({ approver.watchTeams.contains($0).not })
        guard unknown.isEmpty
        else { throw Thrown("Not watching teams: \(unknown.joined(separator: ", "))") }
        approver.watchTeams = approver.watchTeams.subtracting(teams)
      case .watchAuthors(let authors):
        let known = approvers.values.reduce(into: Set(), { $0.insert($1.login) })
        let unknown = authors.filter({ known.contains($0).not })
        guard unknown.isEmpty
        else { throw Thrown("Unknown users: \(unknown.joined(separator: ", "))") }
        approver.watchAuthors.formUnion(authors)
      case .watchTeams(let teams):
        let known = rules.teams.values.reduce(into: Set(), { $0.insert($1.name) })
        let unknown = teams.filter({ known.contains($0).not })
        guard unknown.isEmpty
        else { throw Thrown("Unknown teams: \(unknown.joined(separator: ", "))") }
        approver.watchTeams.formUnion(teams)
      }
      approvers[user] = approver
    }
    return try persistAsset(.init(
      cfg: cfg,
      asset: fusion.approval.approvers,
      content: Fusion.Approval.Approver.serialize(approvers: approvers),
      message: generate(cfg.createApproversCommitMessage(
        fusion: fusion,
        user: user,
        command: command
      ))
    ))
  }
  public func patchReview(
    cfg: Configuration,
    skip: Bool,
    path: String,
    message: String
  ) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    let statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    guard var status = statuses[ctx.review.iid] else { return false }
    guard try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
      .isFirst(review: ctx.review.iid, target: ctx.review.targetBranch)
      .not
    else {
      logMessage(.init(message: "Review is validating"))
      return false
    }
    let patch = try cfg.gitlabCi
      .flatMap({ $0.loadArtifact(job: ctx.job.id, file: path) })
      .map(execute)
      .map(Execute.parseData(reply:))
      .get()
    let initial = try Id(.head)
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let result: Git.Sha?
    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: .make(sha: .make(job: ctx.job)))))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    try Execute.checkStatus(reply: execute(cfg.git.apply(patch: patch)))
    if try Execute.parseLines(reply: execute(cfg.git.changesList)).isEmpty.not {
      try Execute.checkStatus(reply: execute(cfg.git.addAll))
      try Execute.checkStatus(reply: execute(cfg.git.commit(message: message)))
      result = try .make(value: Execute.parseText(reply: execute(cfg.git.getSha(ref: .head))))
    } else {
      result = nil
    }
    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: initial)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    guard let result = result else { return false }
    if skip {
      status.skip.insert(result)
      _ = try persist(
        statuses,
        cfg: cfg,
        fusion: fusion,
        state: ctx.review,
        status: status,
        reason: .skipCommit
      )
    }
    try Execute.checkStatus(reply: execute(cfg.git.push(
      url: cfg.gitlabCi.flatMap(\.protected).get().push,
      branch: .init(name: ctx.review.sourceBranch),
      sha: result,
      force: false,
      secret: cfg.gitlabCi.flatMap(\.protected).get().secret
    )))
    return true
  }
  public func skipReview(
    cfg: Configuration,
    iid: UInt
  ) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let gitlabCi = try cfg.gitlabCi.get()
    let statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    let state = try gitlabCi.getMrState(review: iid)
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    guard var status = statuses[iid] else { return false }
    status.emergent = try .make(value: state.lastPipeline.sha)
    return try persist(
      statuses,
      cfg: cfg,
      fusion: fusion,
      state: state,
      status: status,
      reason: .cheat
    )
  }
  public func approveReview(
    cfg: Configuration,
    resolution: Fusion.Approval.Status.Resolution
  ) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    guard try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
      .isFirst(review: ctx.review.iid, target: ctx.review.targetBranch)
      .not
    else {
      logMessage(.init(message: "Review is validating"))
      return false
    }
    let statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    guard let status = statuses[ctx.review.iid] else {
      logMessage(.init(message: "No review \(ctx.review.iid)"))
      return false
    }
    var review = try resolveReview(
      cfg: cfg,
      state: ctx.review,
      fusion: fusion,
      kind: fusion.makeKind(state: ctx.review, project: ctx.project),
      approvers: resolveApprovers(cfg: cfg, fusion: fusion),
      status: status
    )
    try review.approve(job: ctx.job, resolution: resolution)
    return try persist(
      statuses,
      cfg: cfg,
      fusion: fusion,
      state: ctx.review,
      status: review.status,
      reason: .approve
    )
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
    else {
      logMessage(.init(message: "Review is validating"))
      return false
    }
    let statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    guard let status = statuses[ctx.review.iid] else {
      logMessage(.init(message: "No review \(ctx.review.iid)"))
      return false
    }
    var review = try resolveReview(
      cfg: cfg,
      state: ctx.review,
      fusion: fusion,
      kind: fusion.makeKind(state: ctx.review, project: ctx.project),
      approvers: resolveApprovers(cfg: cfg, fusion: fusion),
      status: status
    )
    try review.setAuthor(job: ctx.job)
    return try persist(
      statuses,
      cfg: cfg,
      fusion: fusion,
      state: ctx.review,
      status: review.status,
      reason: .own
    )
  }
  public func unownReview(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try resolveReviewContext(cfg: cfg)
    guard ctx.isActual else { return false }
    guard try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
      .isFirst(review: ctx.review.iid, target: ctx.review.targetBranch)
      .not
    else {
      logMessage(.init(message: "Review is validating"))
      return false
    }
    let statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    guard let status = statuses[ctx.review.iid] else {
      logMessage(.init(message: "No review \(ctx.review.iid)"))
      return false
    }
    var review = try resolveReview(
      cfg: cfg,
      state: ctx.review,
      fusion: fusion,
      kind: fusion.makeKind(state: ctx.review, project: ctx.project),
      approvers: resolveApprovers(cfg: cfg, fusion: fusion),
      status: status
    )
    guard try review.unsetAuthor(job: ctx.job) else {
      logMessage(.init(message: "Not an author: \(ctx.job.user.username)"))
      return false
    }
    return try persist(
      statuses,
      cfg: cfg,
      fusion: fusion,
      state: ctx.review,
      status: review.status,
      reason: .unown
    )
  }
  public func startReplication(cfg: Configuration) throws -> Bool {
    let fusion = try resolveFusion(.init(cfg: cfg))
    let gitlabCi = try cfg.gitlabCi.get()
    let project = try gitlabCi.getProject
      .map(execute)
      .reduce(Json.GitlabProject.self, jsonDecoder.decode(success:reply:))
      .get()
    let merge = try Fusion.Merge.makeReplication(
      fork: .make(value: gitlabCi.job.pipeline.sha),
      subject: .init(name: gitlabCi.job.pipeline.ref),
      project: project
    )
    let blockers = try checkMergeBlockers(cfg: cfg, merge: merge)
    guard blockers.isEmpty else {
      blockers.map(\.logMessage).forEach(logMessage)
      return false
    }
    try createReview(
      cfg: cfg,
      gitlab: cfg.gitlabCi.get(),
      merge: merge,
      title: generate(cfg.createReplicationCommitMessage(
        replication: fusion.replication,
        review: nil,
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
    let merge = try Fusion.Merge.makeIntegration(
      fork: .make(value: fork),
      subject: .init(name: source),
      target: .init(name: target)
    )
    let blockers = try checkMergeBlockers(cfg: cfg, merge: merge)
    guard blockers.isEmpty else {
      blockers.map(\.logMessage).forEach(logMessage)
      return false
    }
    try createReview(
      cfg: cfg,
      gitlab: cfg.gitlabCi.get(),
      merge: merge,
      title: generate(cfg.createIntegrationCommitMessage(
        integration: fusion.integration,
        review: nil,
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
    let kind = try fusion.makeKind(state: ctx.review, project: ctx.project)
    var statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    let approvers = try resolveApprovers(cfg: cfg, fusion: fusion)
    var review = try resolveReview(
      cfg: cfg,
      state: ctx.review,
      fusion: fusion,
      kind: kind,
      approvers: approvers,
      status: resolveStatus(
        cfg: cfg,
        approvers: approvers,
        state: ctx.review,
        fusion: fusion,
        kind: kind,
        statuses: &statuses
      )
    )
    guard try checkIsFastForward(cfg: cfg, state: ctx.review) else {
      if let sha = try syncReview(cfg: cfg, fusion: fusion, state: ctx.review, kind: kind) {
        try Execute.checkStatus(reply: execute(cfg.git.push(
          url: ctx.gitlab.protected.get().push,
          branch: .init(name: ctx.review.sourceBranch),
          sha: sha,
          force: false,
          secret: ctx.gitlab.protected.get().secret
        )))
      } else {
        report(cfg.reportReviewMergeConflicts(review: review, state: ctx.review))
        try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
      }
      return false
    }
    if let blockers = try checkReviewBlockers(cfg: cfg, state: ctx.review, review: review) {
      try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
      blockers.map(\.logMessage).forEach(logMessage)
      report(cfg.reportReviewBlocked(review: review, state: ctx.review, reasons: blockers))
      return false
    }
    let approval = try verify(cfg: cfg, state: ctx.review, fusion: fusion, review: &review)
    report(cfg.reportReviewUpdated(review: review, state: ctx.review, update: approval))
    guard approval.state.isApproved else {
      logMessage(.init(message: "Review is not approved"))
      try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
      _ = try persist(statuses, cfg: cfg, fusion: fusion, state: ctx.review, status: review.status, reason: .update)
      return false
    }
    guard try checkIsSquashed(cfg: cfg, state: ctx.review, kind: review.kind) else {
      let sha = try squashReview(cfg: cfg, state: ctx.review, fusion: fusion, review: review)
      try Execute.checkStatus(reply: execute(cfg.git.push(
        url: ctx.gitlab.protected.get().push,
        branch: .init(name: ctx.review.sourceBranch),
        sha: sha,
        force: true,
        secret: ctx.gitlab.protected.get().secret
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
    let kind = try fusion.makeKind(state: ctx.review, project: ctx.project)
    let approvers = try resolveApprovers(cfg: cfg, fusion: fusion)
    let review = try resolveReview(
      cfg: cfg,
      state: ctx.review,
      fusion: fusion,
      kind: kind,
      approvers: approvers,
      status: resolveStatus(
        cfg: cfg,
        approvers: approvers,
        state: ctx.review,
        fusion: fusion,
        kind: kind,
        statuses: &statuses
      )
    )
    guard
      try checkIsFastForward(cfg: cfg, state: ctx.review),
      try checkIsSquashed(cfg: cfg, state: ctx.review, kind: review.kind),
      try checkReviewBlockers(cfg: cfg, state: ctx.review, review: review) == nil,
      review.isApproved(state: ctx.review)
    else {
      try changeQueue(cfg: cfg, state: ctx.review, fusion: fusion, enqueue: false)
      try cfg.gitlabCi
        .flatReduce(curry: ctx.review.iid, GitlabCi.postMrPipelines(review:))
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
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
          review: ctx.review,
          merge: merge
        ))
      ) else { return false }
      if let merge = try shiftReplication(cfg: cfg, merge: merge, project: ctx.project) {
        try createReview(
          cfg: cfg,
          gitlab: ctx.gitlab,
          merge: merge,
          title: generate(cfg.createReplicationCommitMessage(
            replication: fusion.replication,
            review: nil,
            merge: merge
          ))
        )
      }
    case .integration(let merge):
      guard try acceptReview(
        cfg: cfg,
        state: ctx.review,
        review: review,
        message: generate(cfg.createIntegrationCommitMessage(
          integration: fusion.integration,
          review: ctx.review,
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
    guard state.state == "opened" else { throw Thrown("Merge state: \(state.state)") }
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
      thread: thread,
      fork: kind.merge?.fork
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
      location: file,
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
    kind: Fusion.Kind,
    approvers: [String: Fusion.Approval.Approver],
    status: Fusion.Approval.Status
  ) throws -> Review {
    logMessage(.init(message: "Loading status assets"))
    return try Review.make(
      bot: cfg.gitlabCi.get().protected.get().user.username,
      status: status,
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
      try review.resolveOwnage(diff: listMergeChanges(
        cfg: cfg,
        ref: .make(sha: current),
        parents: [target, .make(sha: fork)]
      ))
    } else {
      try review.resolveOwnage(diff: Execute.parseLines(
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
    return review.resolveApproval(sha: current)
  }
  func checkMergeBlockers(
    cfg: Configuration,
    merge: Fusion.Merge
  ) throws -> [Report.ReviewBlocked.Reason] {
    var result: [Report.ReviewBlocked.Reason] = []
    if try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(remote: merge.target),
      parent: .make(sha: merge.fork)
    ))) { result.append(.forkInTarget) }
    if try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(remote: merge.subject),
      parent: .make(sha: merge.fork)
    ))).not { result.append(.forkNotInSubject) }
    guard .replicate == merge.prefix else { return result }
    if try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(remote: merge.target),
      parent: .make(sha: merge.fork).make(parent: 1)
    ))).not { result.append(.forkParentNotInTarget) }
    return result
  }
  func checkReviewBlockers(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    review: Review
  ) throws -> [Report.ReviewBlocked.Reason]? {
    logMessage(.init(message: "Checking blocking reasons"))
    var result: [Report.ReviewBlocked.Reason] = []
    let source = try resolveBranch(cfg: cfg, name: review.kind.source.name)
    if source.protected { result.append(.sourceIsProtected) }
    let target = try resolveBranch(cfg: cfg, name: state.targetBranch)
    if target.protected.not { result.append(.targetNotProtected) }
    let bot = try cfg.gitlabCi.get().protected.get().user.username
    if state.draft { result.append(.draft) }
    if state.workInProgress { result.append(.workInProgress) }
    if !state.blockingDiscussionsResolved { result.append(.discussions) }
    if
      let sanity = review.rules.sanity,
      !cfg.profile.checkSanity(criteria: review.ownage[sanity])
    { result.append(.sanity) }
    if review.unknownUsers.isEmpty.not { result.append(.unknownUsers) }
    if review.unknownTeams.isEmpty.not { result.append(.unknownTeams) }
    let excludes: [Git.Ref]
    switch review.kind {
    case .proposition(let merge):
      if !state.squash { result.append(.squashStatus) }
      if state.author.username == bot { result.append(.authorIsBot) }
      if let rule = merge.rule {
        if !rule.title.isMet(state.title) { result.append(.badTitle) }
        if let task = rule.task {
          let source = try findMatches(in: state.sourceBranch, regexp: task)
          let title = try findMatches(in: state.title, regexp: task)
          if source.symmetricDifference(title).isEmpty.not { result.append(.taskMismatch) }
        }
      } else { result.append(.noSourceRule) }
      try excludes = [.make(remote: .init(name: state.targetBranch))]
    case .replication(let merge), .integration(let merge):
      result += try checkMergeBlockers(cfg: cfg, merge: merge)
      if state.author.username != bot { result.append(.authorNotBot) }
      if try !Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.source),
        parent: .make(sha: merge.fork)
      ))) { result.append(.forkNotInSource) }
      if merge.prefix == .replicate, target.default.not { result.append(.targetNotDefault) }
      let subject = try resolveBranch(cfg: cfg, name: merge.subject.name)
      if subject.protected.not { result.append(.subjectNotProtected) }

      if state.squash { result.append(.squashStatus) }
      if state.targetBranch != merge.target.name { result.append(.forkTargetMismatch) }
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
  func checkIsFastForward(
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
    return parents == [target, fork]
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
  func syncReview(
    cfg: Configuration,
    fusion: Fusion,
    state: Json.GitlabReviewState,
    kind: Fusion.Kind
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
    let message: String
    switch kind {
    case .proposition: message = try generate(cfg.createPropositionCommitMessage(
      proposition: fusion.proposition,
      review: state
    ))
    case .replication(let merge): message = try generate(cfg.createReplicationCommitMessage(
      replication: fusion.replication,
      review: state,
      merge: merge
    ))
    case .integration(let merge): message = try generate(cfg.createIntegrationCommitMessage(
      integration: fusion.integration,
      review: state,
      merge: merge
    ))
    }
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
    review: Review
  ) throws -> Git.Sha {
    logMessage(.init(message: "Squashing source commits"))
    let message: String
    let merge: Fusion.Merge
    switch review.kind {
    case .proposition: throw MayDay("Squashing proposition")
    case .replication(let replication):
      merge = replication
      message = try generate(cfg.createReplicationCommitMessage(
        replication: fusion.replication,
        review: state,
        merge: merge
      ))
    case .integration(let integration):
      merge = integration
      message = try generate(cfg.createIntegrationCommitMessage(
        integration: fusion.integration,
        review: state,
        merge: merge
      ))
    }
    let fork = Git.Ref.make(sha: merge.fork)
    let name = try Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: fork)))
    let email = try Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: fork)))
    return try Git.Sha.make(value: Execute.parseText(reply: execute(cfg.git.commitTree(
      tree: .init(ref: .make(sha: .make(value: state.lastPipeline.sha))),
      message: message,
      parents: [.make(remote: merge.target), fork],
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
        delete: .init(name: state.sourceBranch),
        secret: gitlab.protected.get().secret
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
          mergeCommitMessage: review.kind.proposition.else(message),
          squashCommitMessage: review.kind.proposition.then(message),
          squash: review.kind.proposition,
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
    merge: Fusion.Merge,
    project: Json.GitlabProject
  ) throws -> Fusion.Merge? {
    let fork = try Id
      .make(cfg.git.listCommits(
        in: [.make(remote: merge.subject)],
        notIn: [.make(sha: merge.fork)],
        firstParents: true
      ))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .last
      .map(Git.Sha.make(value:))
    guard let fork = fork else { return nil }
    return try .makeReplication(fork: fork, subject: merge.subject, project: project)
  }
  func createReview(
    cfg: Configuration,
    gitlab: GitlabCi,
    merge: Fusion.Merge,
    title: String
  ) throws {
    guard try !Execute.parseSuccess(reply: execute(cfg.git.checkObjectType(
      ref: .make(remote: merge.source)
    ))) else {
      logMessage(.init(message: "Fusion already in progress"))
      return
    }
    try Id
      .make(cfg.git.push(
        url: gitlab.protected.get().push,
        branch: merge.source,
        sha: merge.fork,
        force: false,
        secret: gitlab.protected.get().secret
      ))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try gitlab
      .postMergeRequests(parameters: .init(
        sourceBranch: merge.source.name,
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
    logMessage(.init(message: "Persisting review statuses"))
    var statuses = statuses
    if let state = state { statuses[state.iid] = status }
    return try persistAsset(.init(
      cfg: cfg,
      asset: fusion.approval.statuses,
      content: Fusion.Approval.Status.serialize(statuses: statuses),
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
    logMessage(.init(message: "Resolving authors"))
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
    let project = try gitlabCi.getProject
      .map(execute)
      .reduce(Json.GitlabProject.self, jsonDecoder.decode(success:reply:))
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
      project: project,
      isLastPipe: job.pipeline.id == review.lastPipeline.id
    )
  }
  func resolveApprovers(
    cfg: Configuration,
    fusion: Fusion
  ) throws -> [String: Fusion.Approval.Approver] { try Id
    .make(.init(git: cfg.git, file: .make(asset: fusion.approval.approvers)))
    .map(parseApprovers)
    .get()
    .map(Fusion.Approval.Approver.make(login:yaml:))
    .reduce(into: [:], { $0[$1.login] = $1 })
  }
  func resolveRules(cfg: Configuration, fusion: Fusion) throws -> Fusion.Approval.Rules { try Id
    .make(.init(git: cfg.git, file: .make(asset: fusion.approval.rules)))
    .map(parseApprovalRules)
    .map(Fusion.Approval.Rules.make(yaml:))
    .get()
  }
}
