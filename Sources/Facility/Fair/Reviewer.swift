import Foundation
import Facility
import FacilityPure
public final class Reviewer {
  let execute: Try.Reply<Execute>
  let parseFusion: Try.Reply<ParseYamlFile<Fusion>>
  let parseFusionStatuses: Try.Reply<ParseYamlFile<[UInt: Fusion.Approval.Status]>>
  let parseReviewQueue: Try.Reply<ParseYamlFile<Fusion.Queue>>
  let parseApprovers: Try.Reply<ParseYamlFile<[String: Fusion.Approval.Approver]>>
  let parseApprovalRules: Try.Reply<ParseYamlSecret<Fusion.Approval.Rules>>
  let parseCodeOwnage: Try.Reply<ParseYamlFile<[String: Criteria]>>
  let parseProfile: Try.Reply<ParseYamlFile<Configuration.Profile>>
  let parseHaters: Try.Reply<ParseYamlSecret<[String: Set<String>]>>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  let writeStdout: Act.Of<String>.Go
  let generate: Try.Reply<Generate>
  let report: Act.Reply<Report>
  let readStdin: Try.Reply<Configuration.ReadStdin>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    parseFusion: @escaping Try.Reply<ParseYamlFile<Fusion>>,
    parseFusionStatuses: @escaping Try.Reply<ParseYamlFile<[UInt: Fusion.Approval.Status]>>,
    parseReviewQueue: @escaping Try.Reply<ParseYamlFile<Fusion.Queue>>,
    parseApprovers: @escaping Try.Reply<ParseYamlFile<[String: Fusion.Approval.Approver]>>,
    parseApprovalRules: @escaping Try.Reply<ParseYamlSecret<Fusion.Approval.Rules>>,
    parseCodeOwnage: @escaping Try.Reply<ParseYamlFile<[String: Criteria]>>,
    parseProfile: @escaping Try.Reply<ParseYamlFile<Configuration.Profile>>,
    parseHaters: @escaping Try.Reply<ParseYamlSecret<[String: Set<String>]>>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
    writeStdout: @escaping Act.Of<String>.Go,
    generate: @escaping Try.Reply<Generate>,
    report: @escaping Act.Reply<Report>,
    readStdin: @escaping Try.Reply<Configuration.ReadStdin>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.parseFusion = parseFusion
    self.parseFusionStatuses = parseFusionStatuses
    self.parseReviewQueue = parseReviewQueue
    self.parseApprovers = parseApprovers
    self.parseApprovalRules = parseApprovalRules
    self.parseCodeOwnage = parseCodeOwnage
    self.parseProfile = parseProfile
    self.parseHaters = parseHaters
    self.persistAsset = persistAsset
    self.writeStdout = writeStdout
    self.generate = generate
    self.report = report
    self.readStdin = readStdin
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func reportCustom(
    cfg: Configuration,
    event: String,
    stdin: Configuration.ReadStdin
  ) throws -> Bool {
    let stdin = try readStdin(stdin)
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
    guard let status = try resolveStatus(cfg: cfg, fusion: fusion, statuses: statuses)
    else { return false }
    report(status.reportReviewCustom(
      cfg: cfg,
      event: event,
      stdin: stdin
    ))
    return true
  }
  public func cleanReviews(cfg: Configuration, remind: Bool) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let approvers = try parseApprovers(cfg.parseApprovers(approval: fusion.approval))
    var statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
    let gitlab = try cfg.gitlab.get()
    for status in statuses.values {
      let state = try gitlab.getMrState(review: status.review)
        .map(execute)
        .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
        .get()
      guard state.state != "closed" else {
        report(status.reportReviewClosed(cfg: cfg))
        statuses[state.iid] = nil
        continue
      }
      guard remind else { continue }
      let reminds = status.reminds(sha: state.lastPipeline.sha, approvers: approvers)
      guard reminds.isEmpty.not else { continue }
      report(status.reportReviewRemind(cfg: cfg, slackers: reminds))
    }
    try persist(statuses, cfg: cfg, fusion: fusion, state: nil, status: nil, reason: .clean)
    return true
  }
  public func updateApprover(
    cfg: Configuration,
    gitlab: String,
    command: Fusion.Approval.Approver.Command
  ) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let rules = try parseApprovalRules(cfg.parseApproalRules(approval: fusion.approval))
    var approvers = try parseApprovers(cfg.parseApprovers(approval: fusion.approval))
    let user = try gitlab.isEmpty
      .else(gitlab)
      .get(cfg.gitlab.get().job.user.username)
    if case .register(let chat) = command {
      approvers[user] = approvers[user].get(.make(login: user, active: true))
      if let slack = chat[.slack].filter(isIncluded: \.isEmpty.not) {
        #warning("tbd")
      }
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
      message: generate(fusion.createApproversCommitMessage(
        cfg: cfg,
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
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.review.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    let statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
    guard var status = statuses[merge.iid] else { return false }
    guard try parseReviewQueue(cfg.parseReviewQueue(fusion: fusion))
      .isFirst(review: merge.iid, target: merge.targetBranch)
      .not
    else {
      logMessage(.init(message: "Review is validating"))
      return false
    }
    let patch = try cfg.gitlab
      .flatMap({ $0.loadArtifact(job: parent.id, file: path) })
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
    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: .make(sha: .make(job: parent)))))
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
      try persist(
        statuses,
        cfg: cfg,
        fusion: fusion,
        state: merge,
        status: status,
        reason: .skipCommit
      )
    }
    try Execute.checkStatus(reply: execute(cfg.git.push(
      url: cfg.gitlab.flatMap(\.protected).get().push,
      branch: .init(name: merge.sourceBranch),
      sha: result,
      force: false,
      secret: cfg.gitlab.flatMap(\.protected).get().secret
    )))
    return true
  }
  public func skipReview(
    cfg: Configuration,
    iid: UInt
  ) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let gitlab = try cfg.gitlab.get()
    let statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
    let state = try gitlab.getMrState(review: iid)
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
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.review.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    guard try parseReviewQueue(cfg.parseReviewQueue(fusion: fusion))
      .isFirst(review: merge.iid, target: merge.targetBranch)
      .not
    else {
      logMessage(.init(message: "Review is validating"))
      return false
    }
    let statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
    guard var status = statuses[merge.iid] else {
      logMessage(.init(message: "No review \(merge.iid)"))
      return false
    }
    let approvers = try parseApprovers(cfg.parseApprovers(approval: fusion.approval))
    try status.approve(job: parent, approvers: approvers, resolution: resolution)
    return try persist(
      statuses,
      cfg: cfg,
      fusion: fusion,
      state: merge,
      status: status,
      reason: .approve
    )
  }
  public func dequeueReview(cfg: Configuration) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.review.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    guard try changeQueue(cfg: cfg, fusion: fusion, enqueue: false).not
    else { return true }
    logMessage(.init(message: "Triggering new pipeline"))
    try cfg.gitlab
      .flatReduce(curry: merge.iid, Gitlab.postMrPipelines(review:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return false
  }
  public func ownReview(cfg: Configuration) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.review.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    guard try parseReviewQueue(cfg.parseReviewQueue(fusion: fusion))
      .isFirst(review: merge.iid, target: merge.targetBranch)
      .not
    else {
      logMessage(.init(message: "Review is validating"))
      return false
    }
    let statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
    guard var status = statuses[merge.iid] else {
      logMessage(.init(message: "No review \(merge.iid)"))
      return false
    }
    let approvers = try parseApprovers(cfg.parseApprovers(approval: fusion.approval))
    let rules = try parseApprovalRules(cfg.parseApproalRules(approval: fusion.approval))
    guard try status.setAuthor(job: parent, approvers: approvers, rules: rules)
    else {
      logMessage(.init(message: "Already is author: \(parent.user.username)"))
      return false
    }
    return try persist(
      statuses,
      cfg: cfg,
      fusion: fusion,
      state: merge,
      status: status,
      reason: .own
    )
  }
  public func unownReview(cfg: Configuration) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.review.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    guard try parseReviewQueue(cfg.parseReviewQueue(fusion: fusion))
      .isFirst(review: merge.iid, target: merge.targetBranch)
      .not
    else {
      logMessage(.init(message: "Review is validating"))
      return false
    }
    let statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
    guard var status = statuses[merge.iid] else {
      logMessage(.init(message: "No review \(merge.iid)"))
      return false
    }
    let approvers = try parseApprovers(cfg.parseApprovers(approval: fusion.approval))
    guard try status.unsetAuthor(job: parent, approvers: approvers) else {
      logMessage(.init(message: "Not an author: \(parent.user.username)"))
      return false
    }
    return try persist(
      statuses,
      cfg: cfg,
      fusion: fusion,
      state: merge,
      status: status,
      reason: .unown
    )
  }
  public func startReplication(cfg: Configuration) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let gitlab = try cfg.gitlab.get()
    let project = try gitlab.project.get()
    let merge = try fusion.makeReplication(
      fork: .make(value: gitlab.job.pipeline.sha),
      original: .init(name: gitlab.job.pipeline.ref),
      project: project
    )
    let stoppers = try checkMergeStoppers(cfg: cfg, merge: merge)
    guard stoppers.isEmpty else {
      stoppers.map(\.logMessage).forEach(logMessage)
      return false
    }
    try createReview(cfg: cfg, infusion: .merge(merge))
    return true
  }
  public func startIntegration(
    cfg: Configuration,
    source: String,
    target: String,
    fork: String
  ) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let merge = try fusion.makeIntegration(
      fork: .make(value: fork),
      original: .init(name: source),
      target: .init(name: target)
    )
    let stoppers = try checkMergeStoppers(cfg: cfg, merge: merge)
    guard stoppers.isEmpty else {
      stoppers.map(\.logMessage).forEach(logMessage)
      return false
    }
    try createReview(cfg: cfg, infusion: .merge(merge))
    return true
  }
  public func renderIntegration(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.env.parent.get()
    let job = try gitlab.getJob(id: parent.job)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let fusion = try cfg.parseFusion.map(parseFusion).get()
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
    try writeStdout(generate(fusion.exportIntegrationTargets(
      cfg: cfg,
      fork: fork,
      source: source.name,
      targets: targets.map(\.name)
    )))
    return true
  }
  public func updateReview(cfg: Configuration) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.review.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    let statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
    guard let status = try resolveStatus(cfg: cfg, fusion: fusion, statuses: statuses) else {
      try changeQueue(cfg: cfg, fusion: fusion, enqueue: false)
      return false
    }
    guard try checkIsFastForward(cfg: cfg, state: merge) else {
      if let sha = try syncReview(cfg: cfg, fusion: fusion) {
        try Execute.checkStatus(reply: execute(cfg.git.push(
          url: gitlab.protected.get().push,
          branch: .init(name: merge.sourceBranch),
          sha: sha,
          force: false,
          secret: gitlab.protected.get().secret
        )))
      } else {
        report(status.reportReviewMergeConflicts(cfg: cfg))
        try changeQueue(cfg: cfg, fusion: fusion, enqueue: false)
      }
      return false
    }
    guard var review = try resolveReview(cfg: cfg, fusion: fusion, status: status) else {
      try changeQueue(cfg: cfg, fusion: fusion, enqueue: false)
      return false
    }
    let approval = try verify(cfg: cfg, state: merge, fusion: fusion, review: &review)
    report(review.reportReviewUpdated(cfg: cfg, update: approval))
    guard approval.state.isApproved else {
      logMessage(.init(message: "Review is not approved"))
      try changeQueue(cfg: cfg, fusion: fusion, enqueue: false)
      try persist(
        statuses,
        cfg: cfg,
        fusion: fusion,
        state: merge,
        status: review.status,
        reason: .update
      )
      return false
    }
    guard try checkIsSquashed(cfg: cfg, state: merge, infusion: review.infusion) else {
      let sha = try squashReview(cfg: cfg, fusion: fusion, infusion: review.infusion)
      try Execute.checkStatus(reply: execute(cfg.git.push(
        url: gitlab.protected.get().push,
        branch: .init(name: merge.sourceBranch),
        sha: sha,
        force: true,
        secret: gitlab.protected.get().secret
      )))
      logMessage(.init(message: "Updating approves commits"))
      review.squashApproves(sha: sha)
      try persist(statuses, cfg: cfg, fusion: fusion, state: merge, status: review.status, reason: .update)
      return false
    }
    try persist(statuses, cfg: cfg, fusion: fusion, state: merge, status: review.status, reason: .update)
    return try changeQueue(cfg: cfg, fusion: fusion, enqueue: true)
  }
  public func acceptReview(cfg: Configuration) throws -> Bool {
    let fusion = try cfg.parseFusion.map(parseFusion).get()
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.review.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    let queue = try parseReviewQueue(cfg.parseReviewQueue(fusion: fusion))
    guard queue.isFirst(review: merge.iid, target: merge.targetBranch)
    else { return false }
    let statuses = try parseFusionStatuses(cfg.parseFusionStatuses(approval: fusion.approval))
    guard let status = try resolveStatus(cfg: cfg, fusion: fusion, statuses: statuses) else {
      try changeQueue(cfg: cfg, fusion: fusion, enqueue: false)
      return false
    }
    guard let review = try resolveReview(cfg: cfg, fusion: fusion, status: status) else {
      try changeQueue(cfg: cfg, fusion: fusion, enqueue: false)
      return false
    }
    guard
      try checkIsFastForward(cfg: cfg, state: merge),
      try checkIsSquashed(cfg: cfg, state: merge, infusion: review.infusion),
      review.isApproved(state: merge)
    else {
      try changeQueue(cfg: cfg, fusion: fusion, enqueue: false)
      try gitlab.postMrPipelines(review: merge.iid)
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
      return false
    }
    try changeQueue(cfg: cfg, fusion: fusion, enqueue: false)
    guard try acceptReview(
      cfg: cfg,
      state: merge,
      review: review,
      message: generate(review.infusion.createFusionCommitMessage(cfg: cfg))
    ) else { return false }
    if let merge = try shiftReplication(cfg: cfg, fusion: fusion, infusion: review.infusion) {
      try createReview(cfg: cfg, infusion: .merge(merge))
    }
    try persist(statuses, cfg: cfg, fusion: fusion, state: merge, status: nil, reason: .merge)
    return true
  }
  func resolveStatus(
    cfg: Configuration,
    fusion: Fusion,
    statuses: [UInt: Fusion.Approval.Status]
  ) throws -> Fusion.Approval.Status? {
    let review = try cfg.gitlab.get().review.get()
    if let status = statuses[review.iid] { return status }
    guard review.state == "opened" else {
      logMessage(.init(message: "Review state: \(review.state)"))
      return nil
    }
    let authors = try resolveAuthors(cfg: cfg)
    let status = Fusion.Approval.Status.make(
      review: review.iid,
      target: review.targetBranch,
      authors: authors
    )
    try persist(statuses, cfg: cfg, fusion: fusion, state: review, status: status, reason: .create)
    report(status.reportReviewCreated(cfg: cfg))
    return status
  }
  func resolveOwnage(
    cfg: Configuration,
    state: Json.GitlabReviewState
  ) throws -> [String: Criteria] { try cfg.gitlab
    .flatMap(\.env.parent)
    .map(\.profile)
    .reduce(.make(sha: .make(value: state.lastPipeline.sha)), Git.File.init(ref:path:))
    .map(cfg.parseProfile(file:))
    .map(parseProfile)
    .map(cfg.parseCodeOwnage(profile:))
    .get()
    .map(parseCodeOwnage)
    .get([:])
  }
  func resolveReview(
    cfg: Configuration,
    fusion: Fusion,
    status: Fusion.Approval.Status
  ) throws -> Review? {
    logMessage(.init(message: "Loading status assets"))
    let gitlab = try cfg.gitlab.get()
    let review = try gitlab.review.get()
    guard let infusion = try resolveInfusion(cfg: cfg, fusion: fusion, status: status)
    else { return nil }
    let result = try Review.make(
      bot: cfg.gitlab.get().protected.get().user.username,
      status: status,
      approvers: parseApprovers(cfg.parseApprovers(approval: fusion.approval)),
      review: review,
      infusion: infusion,
      blockers: checkReviewBlockers(cfg: cfg, infusion: infusion),
      ownage: resolveOwnage(cfg: cfg, state: review),
      rules: parseApprovalRules(cfg.parseApproalRules(approval: fusion.approval)),
      haters: cfg.parseHaters(approval: fusion.approval)
        .map(parseHaters)
        .get([:])
    )
    var stoppers = result.stoppers
    if !cfg.profile.checkSanity(criteria: result.rules.sanity.flatMap({ result.ownage[$0] }))
    { stoppers.append(.sanity) }
    guard result.stoppers.isEmpty else {
      report(status.reportReviewStopped(
        cfg: cfg,
        reasons: stoppers,
        unknownUsers: result.unknownUsers,
        unknownTeams: result.unknownTeams
      ))
      return nil
    }
    return result
  }
  func verify(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    fusion: Fusion,
    review: inout Review
  ) throws -> Review.Approval {
    logMessage(.init(message: "Validating approves"))
    let fork = review.infusion.merge
      .map(\.fork)
      .map(Git.Ref.make(sha:))
    let current = try Git.Sha.make(value: state.lastPipeline.sha)
    let target = try Git.Ref.make(remote: .init(name: state.targetBranch))
    if let fork = review.infusion.merge?.fork {
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
  func checkMergeStoppers(
    cfg: Configuration,
    merge: Review.State.Infusion.Merge
  ) throws -> [Report.ReviewStopped.Reason] {
    var result: [Report.ReviewStopped.Reason] = []
    if try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(remote: merge.target),
      parent: .make(sha: merge.fork)
    ))) { result.append(.forkInTarget) }
    if try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(remote: merge.original),
      parent: .make(sha: merge.fork)
    ))).not { result.append(.forkNotInOriginal) }
    guard .replicate == merge.prefix else { return result }
    if try Execute.parseSuccess(reply: execute(cfg.git.check(
      child: .make(remote: merge.target),
      parent: .make(sha: merge.fork).make(parent: 1)
    ))).not { result.append(.forkParentNotInTarget) }
    return result
  }
  func resolveInfusion(
    cfg: Configuration,
    fusion: Fusion,
    status: Fusion.Approval.Status
  ) throws -> Review.State.Infusion? {
    let gitlab = try cfg.gitlab.get()
    let review = try gitlab.review.get()
    let project = try gitlab.project.get()
    let bot = try gitlab.protected.get().user.username
    let state = try fusion.makeReviewState(review: review, project: project)
    logMessage(.init(message: "Checking review stoppers"))
    var reasons: [Report.ReviewStopped.Reason] = []
    var infusion: Review.State.Infusion? = nil
    switch state {
    case .confusion(.undefinedInfusion):
      reasons.append(.noSourceRule)
    case .confusion(.multipleInfusions(let rules)):
      reasons.append(.multipleRules)
      logMessage(.init(message: "Multiple rules: \(rules.joined(separator: ", "))"))
    case .confusion(.sourceFormat):
      reasons.append(.sourceFormat)
    case .infusion(let value): infusion = value
    }
    guard let infusion = infusion else {
      report(status.reportReviewStopped(cfg: cfg, reasons: reasons))
      reasons.map(\.logMessage).forEach(logMessage)
      return nil
    }
    let source = try resolveBranch(cfg: cfg, name: infusion.source.name)
    if source.protected { reasons.append(.sourceIsProtected) }
    let target = try resolveBranch(cfg: cfg, name: review.targetBranch)
    if target.protected.not { reasons.append(.targetNotProtected) }
    let excludes: [Git.Ref]
    switch infusion {
    case .squash:
      if review.author.username == bot { reasons.append(.botSquash) }
      try excludes = [.make(remote: .init(name: review.targetBranch))]
    case .merge(let merge):
      reasons += try checkMergeStoppers(cfg: cfg, merge: merge)
      if review.author.username != bot { reasons.append(.notBotMerge) }
      if try !Execute.parseSuccess(reply: execute(cfg.git.check(
        child: .make(remote: merge.source),
        parent: .make(sha: merge.fork)
      ))) { reasons.append(.forkNotInSource) }
      if merge.prefix == .replicate, target.default.not { reasons.append(.targetNotDefault) }
      let original = try resolveBranch(cfg: cfg, name: merge.original.name)
      if original.protected.not { reasons.append(.originalNotProtected) }
      if review.targetBranch != merge.target.name { reasons.append(.forkTargetMismatch) }
      excludes = [.make(remote: merge.target), .make(sha: merge.fork)]
    }
    let head = try Git.Sha.make(value: review.lastPipeline.sha)
    for branch in try resolveProtectedBranches(cfg: cfg) {
      guard let base = try? Execute.parseText(reply: execute(cfg.git.mergeBase(
        .make(remote: branch),
        .make(sha: head)
      ))) else { continue }
      let extras = try Execute.parseLines(reply: execute(cfg.git.listCommits(
        in: [.make(sha: .make(value: base))],
        notIn: excludes
      )))
      guard extras.isEmpty else {
        reasons.append(.extraCommits)
        break
      }
    }
    guard reasons.isEmpty else {
      report(status.reportReviewStopped(cfg: cfg, reasons: reasons))
      reasons.map(\.logMessage).forEach(logMessage)
      return nil
    }
    return infusion
  }
  func checkReviewBlockers(
    cfg: Configuration,
    infusion: Review.State.Infusion
  ) throws -> [Report.ReviewUpdated.Blocker] {
    let merge = try cfg.gitlab.get().review.get()
    logMessage(.init(message: "Checking blocking reasons"))
    var result: [Report.ReviewUpdated.Blocker] = []
    if merge.draft { result.append(.draft) }
    if merge.workInProgress { result.append(.workInProgress) }
    if !merge.blockingDiscussionsResolved { result.append(.discussions) }
    switch infusion {
    case .squash(let squash):
      if !merge.squash { result.append(.squashStatus) }
      if let title = squash.proposition.title, !title.isMet(merge.title)
      { result.append(.badTitle) }
      if let jiraIssue = squash.proposition.jiraIssue {
        let source = try findMatches(in: merge.sourceBranch, regexp: jiraIssue)
        let title = try findMatches(in: merge.title, regexp: jiraIssue)
        if source.symmetricDifference(title).isEmpty.not { result.append(.taskMismatch) }
      }
    case .merge:
      if merge.squash { result.append(.squashStatus) }
    }
    return result
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
    infusion: Review.State.Infusion
  ) throws -> Bool {
    logMessage(.init(message: "Checking squash required"))
    guard let fork = infusion.merge?.fork else { return true }
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
    fusion: Fusion,
    enqueue: Bool
  ) throws -> Bool {
    let review = try cfg.gitlab.get().review.get()
    if enqueue { logMessage(.init(message: "Enqueueing review")) }
    else { logMessage(.init(message: "Dequeueing review")) }
    let gitlab = try cfg.gitlab.get()
    var queue = try parseReviewQueue(cfg.parseReviewQueue(fusion: fusion))
    let notifiables = queue.enqueue(
      review: review.iid,
      target: enqueue.then(review.targetBranch)
    )
    let message = try generate(fusion.createReviewQueueCommitMessage(cfg: cfg, queued: enqueue))
    let result = try persistAsset(.init(
      cfg: cfg,
      asset: fusion.queue,
      content: queue.yaml,
      message: message
    ))
    for notifiable in notifiables {
      try Execute.checkStatus(reply: execute(gitlab.postMrPipelines(review: notifiable).get()))
    }
    guard enqueue else { return result }
    return queue.isFirst(review: review.iid, target: review.targetBranch)
  }
  func syncReview(
    cfg: Configuration,
    fusion: Fusion
  ) throws -> Git.Sha? {
    let review = try cfg.gitlab.get().review.get()
    logMessage(.init(message: "Merging target into source"))
    let initial = try Id(.head)
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
      .get()
    let sha = try Git.Ref.make(sha: .make(value: review.lastPipeline.sha))
    let message = try generate(fusion.createMergeCommitMessage(cfg: cfg))
    let name = try Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: sha)))
    let email = try Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: sha)))
    try Execute.checkStatus(reply: execute(cfg.git.detach(ref: sha)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    do {
      try Execute.checkStatus(reply: execute(cfg.git.merge(
        refs: [.make(remote: .init(name: review.targetBranch))],
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
    fusion: Fusion,
    infusion: Review.State.Infusion
  ) throws -> Git.Sha {
    guard let merge = infusion.merge else { throw MayDay("Not a merge") }
    let review = try cfg.gitlab.get().review.get()
    logMessage(.init(message: "Squashing source commits"))
    let message = try generate(infusion.createFusionCommitMessage(cfg: cfg))
    let fork = Git.Ref.make(sha: merge.fork)
    let name = try Execute.parseText(reply: execute(cfg.git.getAuthorName(ref: fork)))
    let email = try Execute.parseText(reply: execute(cfg.git.getAuthorEmail(ref: fork)))
    return try Git.Sha.make(value: Execute.parseText(reply: execute(cfg.git.commitTree(
      tree: .init(ref: .make(sha: .make(value: review.lastPipeline.sha))),
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
    let gitlab = try cfg.gitlab.get()
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
    let result = try cfg.gitlab.get()
      .putMrMerge(
        parameters: .init(
          mergeCommitMessage: review.infusion.proposition.else(message),
          squashCommitMessage: review.infusion.proposition.then(message),
          squash: review.infusion.proposition,
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
      report(review.reportReviewMerged(cfg: cfg))
      return true
    } else if let message = result?.map?["message"]?.value?.string {
      logMessage(.init(message: message))
      report(review.reportReviewMergeError(cfg: cfg, error: message))
      return false
    } else {
      throw MayDay("Unexpected merge response")
    }
  }
  func shiftReplication(
    cfg: Configuration,
    fusion: Fusion,
    infusion: Review.State.Infusion
  ) throws -> Review.State.Infusion.Merge? {
    let project = try cfg.gitlab.get().project.get()
    guard let merge = infusion.merge, merge.prefix == .replicate else { return nil }
    let fork = try Id
      .make(cfg.git.listCommits(
        in: [.make(remote: merge.original)],
        notIn: [.make(sha: merge.fork)],
        firstParents: true
      ))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .last
      .map(Git.Sha.make(value:))
    guard let fork = fork else { return nil }
    return try fusion.makeReplication(fork: fork, original: merge.original, project: project)
  }
  func createReview(cfg: Configuration, infusion: Review.State.Infusion) throws {
    guard let merge = infusion.merge else { throw MayDay("Not merge") }
    let gitlab = try cfg.gitlab.get()
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
        title: generate(infusion.createFusionCommitMessage(cfg: cfg))
      ))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  @discardableResult func persist(
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
      message: generate(fusion.createFusionStatusesCommitMessage(cfg: cfg, reason: reason))
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
      .gitlab
      .flatReduce(curry: name, Gitlab.getBranch(name:))
      .map(execute)
      .reduce(Json.GitlabBranch.self, jsonDecoder.decode(success:reply:))
      .get()
  }
  func resolveProtectedBranches(cfg: Configuration) throws -> [Git.Branch] {
    var result: [Git.Branch] = []
    var page = 1
    let gitlab = try cfg.gitlab.get()
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
  func resolveAuthors(cfg: Configuration) throws -> Set<String> {
    let gitlab = try cfg.gitlab.get()
    let review = try gitlab.review.get()
    let bot = try gitlab.protected.get().user.username
    guard review.author.username == bot else { return [review.author.username] }
    logMessage(.init(message: "Resolving authors"))
    let commits = try Execute.parseLines(reply: execute(cfg.git.listCommits(
      in: [.make(sha: .make(value: review.lastPipeline.sha))],
      notIn: [.make(remote: .init(name: review.targetBranch))],
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
}
