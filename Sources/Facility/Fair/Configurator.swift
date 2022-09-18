import Foundation
import Facility
import FacilityPure
public final class Configurator {
  let execute: Try.Reply<Execute>
  let decodeYaml: Try.Reply<Yaml.Decode>
  let resolveAbsolute: Try.Reply<Files.ResolveAbsolute>
  let readFile: Try.Reply<Files.ReadFile>
  let generate: Try.Reply<Generate>
  let writeFile: Try.Reply<Files.WriteFile>
  let logMessage: Act.Reply<LogMessage>
  let dialect: AnyCodable.Dialect
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    decodeYaml: @escaping Try.Reply<Yaml.Decode>,
    resolveAbsolute: @escaping Try.Reply<Files.ResolveAbsolute>,
    readFile: @escaping Try.Reply<Files.ReadFile>,
    generate: @escaping Try.Reply<Generate>,
    writeFile: @escaping Try.Reply<Files.WriteFile>,
    logMessage: @escaping Act.Reply<LogMessage>,
    dialect: AnyCodable.Dialect,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.decodeYaml = decodeYaml
    self.resolveAbsolute = resolveAbsolute
    self.readFile = readFile
    self.generate = generate
    self.writeFile = writeFile
    self.logMessage = logMessage
    self.dialect = dialect
    self.jsonDecoder = jsonDecoder
  }
  public func configure(
    profile: String,
    verbose: Bool,
    env: [String: String]
  ) throws -> Configuration {
    let profilePath = try Id(profile)
      .map(Files.ResolveAbsolute.make(path:))
      .map(resolveAbsolute)
      .get()
    let repoPath = profilePath.value
      .components(separatedBy: "/")
      .dropLast()
      .joined(separator: "/")
    var git = try Id(repoPath)
      .map(Files.Absolute.init(value:))
      .reduce(verbose, Git.resolveTopLevel(verbose:path:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Files.Absolute.init(value:))
      .map { try Git.init(verbose: verbose, env: env, root: $0) }
      .get()
    git.lfs = try Id(git.updateLfs)
      .map(execute)
      .map(Execute.parseSuccess(reply:))
      .get()
    try Id(git.fetch)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    let profile = try resolveProfile(query: .init(git: git, file: .init(
      ref: .head,
      path: .init(value: profilePath.value.dropPrefix("\(git.root.value)/"))
    )))
    let gitlab = Lossy(try profile.gitlabCi.get { throw Thrown("GitlabCi not configured") })
    let gitlabEnv = gitlab
      .map(\.trigger)
      .reduce(env, GitlabCi.Env.make(env:trigger:))
    let gitlabJob = gitlabEnv
      .flatMap(\.getJob)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
    let gitlabToken = gitlab
      .map(\.token)
      .reduce(env, parse(env:secret:))
    return try .make(
      verbose: verbose,
      git: git,
      env: env,
      profile: profile,
      templates: profile.templates
        .reduce(git, parse(git:templates:))
        .get([:]),
      context: profile.context
        .reduce(git, parse(git:yaml:)),
      gitlabCi: Lossy(try .make(
        trigger: gitlab.get().trigger,
        env: gitlabEnv.get(),
        job: gitlabJob.get(),
        protected: .init(try .make(
          token: gitlabToken,
          env: gitlabEnv,
          job: gitlabJob,
          user: gitlabEnv
            .flatMap { try $0.getTokenUser(token: gitlabToken.get()) }
            .map(execute)
            .reduce(Json.GitlabUser.self, jsonDecoder.decode(success:reply:))
        ))
      )),
//        .make { try profile.gitlabCi.get { throw Thrown("GitlabCi not configured") }}
//        .map { gitlabCi in try .make(
//          env: env,
//          gitlabCi: gitlabCi,
//          job: GitlabCi.getCurrentJob(env: env)
//            .map(execute)
//            .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:)),
//          user: .error(MayDay("tbd")),
//          apiToken: GitlabCi.isProtected(env: env)
//            .map { try parse(env: env, secret: gitlabCi.apiToken) },
//          pushToken: GitlabCi.isProtected(env: env)
//            .map { try parse(env: env, secret: gitlabCi.pushToken) }
//        )},
      slack: Lossy(try profile.slack.get { throw Thrown("Slack not configured") })
        .map { slack in try .make(
          token: parse(env: env, secret: slack.token),
          signals: dialect.read(
            [String: [Yaml.Slack.Signal]].self,
            from: parse(git: git, yaml: slack.signals
          ))
        )}
    )
  }
  public func resolveRequisition(
    query: Configuration.ResolveRequisition
  ) throws -> Configuration.ResolveRequisition.Reply { try query.cfg.profile.requisition
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce(Yaml.Requisition.self, dialect.read(_:from:))
    .map { yaml in try Requisition.make(
      verbose: query.cfg.verbose,
      env: query.cfg.env,
      yaml: yaml
    )}
    .get()
  }
  public func resolveFusion(
    query: Configuration.ResolveFusion
  ) throws -> Configuration.ResolveFusion.Reply { try query.cfg.profile.fusion
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce(Yaml.Fusion.self, dialect.read(_:from:))
    .map(Fusion.make(yaml:))
    .get()
  }
  public func resolveProduction(
    query: Configuration.ResolveProduction
  ) throws -> Configuration.ResolveProduction.Reply { try query.cfg.profile.production
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce(Yaml.Production.self, dialect.read(_:from:))
    .map(Production.make(yaml:))
    .get()
  }
  public func resolveProductionBuilds(
    query: Configuration.ResolveProductionBuilds
  ) throws -> Configuration.ResolveProductionBuilds.Reply { try Id(query.production.builds)
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([Yaml.Production.Build].self, dialect.read(_:from:))
    .get()
    .map(Production.Build.make(yaml:))
  }
  public func resolveProductionVersions(
    query: Configuration.ResolveProductionVersions
  ) throws -> Configuration.ResolveProductionVersions.Reply { try Id(query.production.versions)
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: String].self, dialect.read(_:from:))
    .get()
  }
  public func resolveProfile(
    query: Configuration.ResolveProfile
  ) throws -> Configuration.ResolveProfile.Reply { try Id(query.file)
    .reduce(query.git, parse(git:yaml:))
    .reduce(Yaml.Profile.self, dialect.read(_:from:))
    .reduce(query.file, Configuration.Profile.make(profile:yaml:))
    .get()
  }
  public func resolveCodeOwnage(
    query: Configuration.ResolveCodeOwnage
  ) throws -> Configuration.ResolveCodeOwnage.Reply { try query.profile.codeOwnage
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: Yaml.Criteria].self, dialect.read(_:from:))
    .get()
    .mapValues(Criteria.init(yaml:))
  }
  public func resolveFileTaboos(
    query: Configuration.ResolveFileTaboos
  ) throws -> Configuration.ResolveFileTaboos.Reply { try query.profile.fileTaboos
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([Yaml.FileTaboo].self, dialect.read(_:from:))
    .get()
    .map(FileTaboo.init(yaml:))
  }
  public func resolveCocoapods(
    query: Configuration.ResolveCocoapods
  ) throws -> Configuration.ResolveCocoapods.Reply { try query.profile.cocoapods
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce(Yaml.Cocoapods.self, dialect.read(_:from:))
    .map(Cocoapods.make(yaml:))
    .get()
  }
  public func persistCocoapods(
    query: Configuration.PersistCocoapods
  ) throws -> Configuration.PersistCocoapods.Reply {
    try writeFile(.init(
      file: query.cfg.profile.cocoapods
        .map { "\(query.cfg.git.root.value)/\($0.path.value)" }
        .map(Files.Absolute.init(value:))
        .get(),
      data: .init(query.cocoapods.yaml.utf8)
    ))
  }
  public func resolveFusionStatuses(
    query: Configuration.ResolveFusionStatuses
  ) throws -> Configuration.ResolveFusionStatuses.Reply { try Id(query.approval.statuses)
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: Yaml.Fusion.Status].self, dialect.read(_:from:))
    .get()
    .reduce(into: [:]) {
      try $0[UInt($1.key).get { throw Thrown("Bad approval asset") }] = .make(yaml: $1.value)
    }
  }
  public func persistFusionStatuses(
    query: Configuration.PersistFusionStatuses
  ) throws -> Configuration.PersistFusionStatuses.Reply {
    let message = try generate(query.cfg.createFusionStatusesCommitMessage(
      asset: query.approval.statuses,
      review: query.review
    ))
    try Execute.checkStatus(reply: execute(query.cfg.git.push(
      url: query.cfg.gitlabCi.flatMap(\.protected).get().push,
      branch: query.approval.statuses.branch,
      sha: persist(
        git: query.cfg.git,
        file: query.approval.statuses.file,
        branch: query.approval.statuses.branch,
        yaml: Fusion.Status.yaml(statuses: query.statuses),
        message: message
      ),
      force: false
    )))
  }
  public func resolveUserActivity(
    query: Configuration.ResolveUserActivity
  ) throws -> Configuration.ResolveUserActivity.Reply { try Id(query.approval.activity)
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: Bool].self, dialect.read(_:from:))
    .get()
  }
  public func resolveReviewQueue(
    query: Fusion.Queue.Resolve
  ) throws -> Fusion.Queue.Resolve.Reply { try Id(query.fusion.queue)
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: [UInt]].self, dialect.read(_:from:))
    .map(Fusion.Queue.make(queue:))
    .get()
  }
  public func persistVersions(
    query: Configuration.PersistVersions
  ) throws -> Configuration.PersistVersions.Reply {
    var versions = query.versions
    versions[query.product.name] = query.version
    let message = try generate(query.cfg.createVersionCommitMessage(
      asset: query.production.versions,
      product: query.product,
      version: query.version
    ))
    try Execute.checkStatus(reply: execute(query.cfg.git.push(
      url: query.pushUrl,
      branch: query.production.versions.branch,
      sha: persist(
        git: query.cfg.git,
        file: query.production.versions.file,
        branch: query.production.versions.branch,
        yaml: versions
          .map { "'\($0.key)': '\($0.value)'\n" }
          .sorted()
          .joined(),
        message: message
      ),
      force: false
    )))
  }
  public func persistBuilds(
    query: Configuration.PersistBuilds
  ) throws -> Configuration.PersistBuilds.Reply {
    let builds = query.builds + [query.build]
    let message = try generate(query.cfg.createBuildCommitMessage(
      asset: query.production.builds,
      build: query.build.build
    ))
    try Execute.checkStatus(reply: execute(query.cfg.git.push(
      url: query.pushUrl,
      branch: query.production.builds.branch,
      sha: persist(
        git: query.cfg.git,
        file: query.production.builds.file,
        branch: query.production.builds.branch,
        yaml: query.production.maxBuildsCount
          .map(builds.suffix(_:))
          .get(builds)
          .map(\.yaml)
          .flatMap(makeYaml(build:))
          .joined(),
        message: message
      ),
      force: false
    )))
  }
  public func persistUserActivity(
    query: Configuration.PersistUserActivity
  ) throws -> Configuration.PersistUserActivity.Reply {
    var userActivity = query.userActivity
    userActivity[query.user] = query.active
    let message = try generate(query.cfg.createUserActivityCommitMessage(
      asset: query.approval.activity,
      user: query.user,
      active: query.active
    ))
    try Execute.checkStatus(reply: execute(query.cfg.git.push(
      url: query.pushUrl,
      branch: query.approval.activity.branch,
      sha: persist(
        git: query.cfg.git,
        file: query.approval.activity.file,
        branch: query.approval.activity.branch,
        yaml: userActivity
          .map { "'\($0.key)': \($0.value)\n" }
          .sorted()
          .joined(),
        message: message
      ),
      force: false
    )))
  }
  public func persistReviewQueue(
    query: Fusion.Queue.Persist
  ) throws -> Fusion.Queue.Persist.Reply {
    let message = try generate(query.cfg.createReviewQueueCommitMessage(
      asset: query.fusion.queue,
      review: query.review,
      queued: query.queued
    ))
    try Execute.checkStatus(reply: execute(query.cfg.git.push(
      url: query.pushUrl,
      branch: query.fusion.queue.branch,
      sha: persist(
        git: query.cfg.git,
        file: query.fusion.queue.file,
        branch: query.fusion.queue.branch,
        yaml: query.reviewQueue.yaml,
        message: message
      ),
      force: false
    )))
  }
  public func resolveSecret(
    query: Configuration.ResolveSecret
  ) throws -> Configuration.ResolveSecret.Reply {
    try parse(env: query.cfg.env, secret: query.secret)
  }
}
extension Configurator {
  func persist(
    git: Git,
    file: Files.Relative,
    branch: Git.Branch,
    yaml: String,
    message: String
  ) throws -> Git.Sha {
    let initial = try Id(.head)
      .map(git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    try Execute.checkStatus(reply: execute(git.detach(ref: .make(remote: branch))))
    try Execute.checkStatus(reply: execute(git.clean))
    try writeFile(.init(
      file: .init(value: "\(git.root.value)/\(file.value)"),
      data: .init(yaml.utf8)
    ))
    try Execute.checkStatus(reply: execute(git.addAll))
    try Execute.checkStatus(reply: execute(git.commit(message: message)))
    let result = try Id(.head)
      .map(git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .get()
    try Execute.checkStatus(reply: execute(git.detach(ref: initial)))
    return result
  }
  func parse(git: Git, yaml: Git.File) throws -> AnyCodable { try Id
    .make(yaml)
    .map(git.cat(file:))
    .map(execute)
    .map(Execute.parseText(reply:))
    .map(Yaml.Decode.init(content:))
    .map(decodeYaml)
    .get()
  }
  func parse(
    env: [String: String],
    secret: Configuration.Secret
  ) throws -> String {
    switch secret {
    case .value(let value): return value
    case .envVar(let envVar): return try env[envVar]
      .get { throw Thrown("No env \(envVar)") }
    case .envFile(let envFile): return try env[envFile]
      .map(Files.Absolute.init(value:))
      .map(Files.ReadFile.init(file:))
      .map(readFile)
      .map(String.make(utf8:))
      .get { throw Thrown("No env \(envFile)") }
    }
  }
  func parse(
    git: Git,
    templates: Git.Dir
  ) throws -> [String: String] {
    var result: [String: String] = [:]
    let files = try Id(templates)
      .map(git.listTreeTrackedFiles(dir:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
    for file in files {
      let template = try file.dropPrefix("\(templates.path.value)/")
      result[template] = try Id(file)
        .map(Files.Relative.init(value:))
        .reduce(templates.ref, Git.File.init(ref:path:))
        .map(git.cat(file:))
        .map(execute)
        .map(Execute.parseText(reply:))
        .get()
    }
    return result
  }
  func makeYaml(build: Yaml.Production.Build) -> [String] {
    ["- build: '\(build.build)'\n", "  sha: '\(build.sha)'\n"]
    + build.branch.map { "  branch: '\($0)'\n" }.array
    + build.review.map { "  review: \($0)\n" }.array
    + build.target.map { "  target: '\($0)'\n" }.array
    + build.product.map { "  product: '\($0)'\n" }.array
    + build.version.map { "  version: '\($0)'\n" }.array
  }
}
