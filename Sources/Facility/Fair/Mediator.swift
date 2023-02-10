import Foundation
import Facility
import FacilityPure
public final class Mediator {
  let execute: Try.Reply<Execute>
  let parseReview: Try.Reply<ParseYamlFile<Review>>
  let parseReviewRules: Try.Reply<ParseYamlSecret<Review.Rules>>
  let parseReviewStorage: Try.Reply<ParseYamlFile<Review.Storage>>
  let parseFlow: Try.Reply<ParseYamlFile<Flow>>
  let parseFlowVersions: Try.Reply<ParseYamlFile<Flow.Versions.Storage>>
  let registerSlackUser: Try.Reply<Slack.RegisterUser>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  let parseStdin: Try.Reply<Configuration.ParseStdin>
  let generate: Try.Reply<Generate>
  let logMessage: Act.Reply<LogMessage>
  let stdoutData: Act.Of<Data>.Go
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    parseReview: @escaping Try.Reply<ParseYamlFile<Review>>,
    parseReviewRules: @escaping Try.Reply<ParseYamlSecret<Review.Rules>>,
    parseReviewStorage: @escaping Try.Reply<ParseYamlFile<Review.Storage>>,
    parseFlow: @escaping Try.Reply<ParseYamlFile<Flow>>,
    parseFlowVersions: @escaping Try.Reply<ParseYamlFile<Flow.Versions.Storage>>,
    registerSlackUser: @escaping Try.Reply<Slack.RegisterUser>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
    parseStdin: @escaping Try.Reply<Configuration.ParseStdin>,
    generate: @escaping Try.Reply<Generate>,
    logMessage: @escaping Act.Reply<LogMessage>,
    stdoutData: @escaping Act.Of<Data>.Go,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.parseReview = parseReview
    self.parseReviewRules = parseReviewRules
    self.parseReviewStorage = parseReviewStorage
    self.parseFlow = parseFlow
    self.parseFlowVersions = parseFlowVersions
    self.registerSlackUser = registerSlackUser
    self.persistAsset = persistAsset
    self.parseStdin = parseStdin
    self.generate = generate
    self.logMessage = logMessage
    self.stdoutData = stdoutData
    self.jsonDecoder = jsonDecoder
  }
  public func signal(
    cfg: Configuration,
    event: String,
    stdin: Configuration.ParseStdin,
    args: [String]
  ) throws -> Bool {
    let stdin = try parseStdin(stdin)
    let gitlab = try cfg.gitlab.get()
    var threads = Report.Threads.make(users: cfg.defaultUsers)
    var authors: [String]? = nil
    var product: String? = nil
    var version: String? = nil
    if let merge = try? gitlab.merge.get() {
      threads.reviews.insert("\(merge.iid)")
      if
        let review = try? cfg.parseReview.map(parseReview).get(),
        let storage = try? parseReviewStorage(cfg.parseReviewStorage(review: review)),
        let state = storage.states[merge.iid]
      {
        threads.users.formUnion(state.authors)
        authors = state.authors.sortedNonEmpty
      }
      return true
    } else if
      let flow = try? cfg.parseFlow.map(parseFlow).get(),
      let versions = try? parseFlowVersions(cfg.parseFlowVersions(flow: flow))
    {
      if let tag = try? Git.Tag.make(job: gitlab.job) {
        threads.tags.insert(tag.name)
        if let release = versions.find(deploy: tag) {
          threads.branches.insert(release.branch.name)
          product = release.product
          version = release.version.value
        }
      } else if
        let branch = try? Git.Branch.make(job: gitlab.job),
        let release = versions.find(release: branch)
      {
        threads.branches.insert(release.branch.name)
        product = release.product
        version = release.version.value
      }
    }
    cfg.reportCustom(
      event: event,
      threads: threads,
      stdin: stdin,
      args: args,
      authors: authors,
      product: product,
      version: version
    )
    return true
  }
  public func loadArtifact(
    cfg: Configuration,
    job: UInt,
    path: String
  ) throws -> Bool {
    guard let data = try? cfg.gitlab
      .flatMap({ $0.loadArtifact(job: job, file: path) })
      .map(execute)
      .map(Execute.parseData(reply:))
      .get()
    else { return false }
    stdoutData(data)
    return true
  }
  public func triggerReview(
    cfg: Configuration,
    iid: UInt
  ) throws -> Bool {
    try cfg.gitlab
      .flatReduce(curry: iid, Gitlab.postMrPipelines(review:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func triggerPipeline(
    cfg: Configuration,
    ref: String,
    context: [String]
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    var variables: [String: String] = [:]
    for variable in context {
      let index = try variable.firstIndex(of: "=")
        .get { throw Thrown("wrong argument format \(variable)") }
      let key = variable[variable.startIndex..<index]
      let value = variable[index..<variable.endIndex].dropFirst()
      variables[.init(key)] = .init(value)
    }
    variables[gitlab.trigger.jobId] = "\(gitlab.job.id)"
    variables[gitlab.trigger.jobName] = gitlab.job.name
    variables[gitlab.trigger.pipeline] = "\(gitlab.job.pipeline.id)"
    try gitlab
      .postTriggerPipeline(cfg: cfg, ref: ref, variables: variables)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func affectPipeline(
    cfg: Configuration,
    id: UInt,
    action: Gitlab.PipelineAction
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    try gitlab
      .affectPipeline(cfg: cfg, pipeline: id, action: action)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func affectJobs(
    cfg: Configuration,
    pipeline: UInt,
    names: [String],
    action: Gitlab.JobAction,
    scopes: [Gitlab.JobScope]
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    var page = 1
    var jobs: [Json.GitlabJob] = []
    while true {
      jobs += try gitlab
        .getJobs(action: action, scopes: scopes, pipeline: pipeline, page: page, count: 100)
        .map(execute)
        .reduce([Json.GitlabJob].self, jsonDecoder.decode(success:reply:))
        .get()
      if jobs.count == page * 100 { page += 1 } else { break }
    }
    let ids = jobs
      .filter({ names.contains($0.name) })
      .reduce(into: [:], { $0[$1.name] = max($0[$1.name].get($1.id), $1.id) })
    guard ids.isEmpty.not else { return false }
    for id in ids.values { try Execute.checkStatus(
      reply: execute(gitlab.postJobsAction(job: id, action: action).get())
    )}
    return true
  }
  public func createReviewPipeline(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.merge.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    try gitlab.postMrPipelines(review: merge.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func addReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.merge.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    let labels = Set(labels)
      .subtracting(merge.labels)
      .joined(separator: ",")
    guard !labels.isEmpty else {
      logMessage(.init(message: "No new labels"))
      return false
    }
    try gitlab
      .putMrState(parameters: .init(addLabels: labels), review: merge.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    logMessage(.init(message: "Labels added: \(labels)"))
    return true
  }
  public func removeReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let merge = try gitlab.merge.get()
    guard parent.pipeline.id == merge.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    let labels = Set(labels)
      .intersection(merge.labels)
      .joined(separator: ",")
    guard !labels.isEmpty else {
      logMessage(.init(message: "Labels not present"))
      return false
    }
    try gitlab
      .putMrState(parameters: .init(removeLabels: labels), review: merge.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    logMessage(.init(message: "Labels removed: \(labels)"))
    return true
  }
  public func updateUser(
    cfg: Configuration,
    login: String,
    command: Gitlab.Storage.Command
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    var storage = gitlab.storage
    try storage.bots.formUnion([gitlab.rest.get().user.username])
    let login = login.isEmpty
      .else(login)
      .get(gitlab.job.user.username)
    if case .register(let servises) = command {
      for servise in servises.keys {
        switch servise {
        case .slack:
          guard let slack = servises[servise], slack.isEmpty.not else { continue }
          try registerSlackUser(.make(cfg: cfg, slack: slack, gitlab: login))
        }
      }
    } else {
      guard var user = storage.users[login] else { throw Thrown("No approver \(login)") }
      switch command {
      case .register: break
      case .activate: user.active = true
      case .deactivate: user.active = false
      case .unwatchAuthors(let authors):
        let unknown = authors.filter({ user.watchAuthors.contains($0).not })
        guard unknown.isEmpty
        else { throw Thrown("Not watching authors: \(unknown.joined(separator: ", "))") }
        user.watchAuthors = user.watchAuthors.subtracting(authors)
      case .unwatchTeams(let teams):
        let unknown = teams.filter({ user.watchTeams.contains($0).not })
        guard unknown.isEmpty
        else { throw Thrown("Not watching teams: \(unknown.joined(separator: ", "))") }
        user.watchTeams = user.watchTeams.subtracting(teams)
      case .watchAuthors(let authors):
        let known = storage.users.values.reduce(into: Set(), { $0.insert($1.login) })
        let unknown = authors.filter({ known.contains($0).not })
        guard unknown.isEmpty
        else { throw Thrown("Unknown users: \(unknown.joined(separator: ", "))") }
        user.watchAuthors.formUnion(authors)
      case .watchTeams(let teams):
        let review = try cfg.parseReview.map(parseReview).get()
        let rules = try parseReviewRules(cfg.parseReviewRules(review: review))
        let known = rules.teams.values.reduce(into: Set(), { $0.insert($1.name) })
        let unknown = teams.filter({ known.contains($0).not })
        guard unknown.isEmpty
        else { throw Thrown("Unknown teams: \(unknown.joined(separator: ", "))") }
        user.watchTeams.formUnion(teams)
      }
      storage.users[login] = user
    }
    return try persistAsset(.init(
      cfg: cfg,
      asset: storage.asset,
      content: storage.serialize(),
      message: generate(cfg.createGitlabStorageCommitMessage(
        user: login,
        gitlab: gitlab,
        command: command
      ))
    ))
  }
}
