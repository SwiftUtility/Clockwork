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
      .map(Git.resolveTopLevel(path:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Files.Absolute.init(value:))
      .map { try Git.init(env: env, root: $0) }
      .get()
    git.lfs = try Id(git.updateLfs)
      .map(execute)
      .map(Execute.parseSuccess(reply:))
      .get()
    try Execute.checkStatus(reply: execute(git.fetch))
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
      .map({ try parse(git: git, env: env, secret: $0) })
    return try .make(
      git: git,
      env: env,
      profile: profile,
      templates: profile.templates
        .reduce(git, parse(git:templates:))
        .get([:]),
      context: profile.context
        .map({ try decodeYaml(.init(content: parse(git: git, env: env, secret: $0))) }),
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
      slack: Lossy(try profile.slack
        .map { slack in try .make(
          token: parse(git: git, env: env, secret: slack.token),
          signals: dialect.read(
            [String: [Yaml.Slack.Signal]].self,
            from: parse(git: git, yaml: slack.signals
          ))
        )}
        .get { throw Thrown("Slack not configured") })
    )
  }
  public func resolveRequisition(
    query: Configuration.ResolveRequisition
  ) throws -> Configuration.ResolveRequisition.Reply { try query.cfg.profile.requisition
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce(Yaml.Requisition.self, dialect.read(_:from:))
    .map { yaml in try Requisition.make(
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
  public func resolveProfile(
    query: Configuration.ResolveProfile
  ) throws -> Configuration.ResolveProfile.Reply { try Id(query.file)
    .reduce(query.git, parse(git:yaml:))
    .reduce(Yaml.Profile.self, dialect.read(_:from:))
    .reduce(query.file, Configuration.Profile.make(profile:yaml:))
    .get()
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
    .reduce([String: Yaml.Fusion.Approval.Status].self, dialect.read(_:from:))
    .get()
    .map(Fusion.Approval.Status.make(review:yaml:))
    .reduce(into: [:], { $0[$1.review] = $1 })
  }
  public func resolveApprovers(
    query: Configuration.ResolveApprovers
  ) throws -> Configuration.ResolveApprovers.Reply { try Id(query.approval.approvers)
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: Yaml.Fusion.Approval.Approver].self, dialect.read(_:from:))
    .get()
    .map(Fusion.Approval.Approver.make(login:yaml:))
    .reduce(into: [:], { $0[$1.login] = $1 })
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
  public func parseYamlFile<T: Decodable>(
    query: Configuration.ParseYamlFile<T>
  ) throws -> T { try Id(query.file)
    .reduce(query.git, parse(git:yaml:))
    .reduce(T.self, dialect.read(_:from:))
    .get()
  }
  public func parseYamlSecret<T: Decodable>(
    query: Configuration.ParseYamlSecret<T>
  ) throws -> T { try Id(parse(git: query.cfg.git, env: query.cfg.env, secret: query.secret))
    .map(Yaml.Decode.init(content:))
    .map(decodeYaml)
    .reduce(T.self, dialect.read(_:from:))
    .get()
  }
  public func persistAsset(
    query: Configuration.PersistAsset
  ) throws -> Configuration.PersistAsset.Reply {
    guard let sha = try persist(
      git: query.cfg.git,
      asset: query.asset,
      yaml: query.content,
      message: query.message
    ) else { return false }
    try Execute.checkStatus(reply: execute(query.cfg.git.push(
      url: query.cfg.gitlabCi.flatMap(\.protected).get().push,
      branch: query.asset.branch,
      sha: sha,
      force: false
    )))
    try Execute.checkStatus(reply: execute(query.cfg.git.fetchBranch(query.asset.branch)))
    let fetched = try Execute.parseText(reply: execute(query.cfg.git.getSha(
      ref: .make(remote: query.asset.branch)
    )))
    guard sha.value == fetched else { throw Thrown("Fetch sha mismatch") }
    return true
  }
  public func resolveSecret(
    query: Configuration.ResolveSecret
  ) throws -> Configuration.ResolveSecret.Reply {
    try parse(git: query.cfg.git, env: query.cfg.env, secret: query.secret)
  }
}
extension Configurator {
  func persist(
    git: Git,
    asset: Configuration.Asset,
    yaml: String,
    message: String
  ) throws -> Git.Sha? {
    let initial = try Id(.head)
      .map(git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.make(value:))
      .map(Git.Ref.make(sha:))
      .get()
    try Execute.checkStatus(reply: execute(git.detach(ref: .make(remote: asset.branch))))
    try Execute.checkStatus(reply: execute(git.clean))
    try writeFile(.init(
      file: .init(value: "\(git.root.value)/\(asset.file.value)"),
      data: .init(yaml.utf8)
    ))
    let result: Git.Sha?
    if try !Execute.parseSuccess(reply: execute(git.notCommited)) {
      try Execute.checkStatus(reply: execute(git.addAll))
      try Execute.checkStatus(reply: execute(git.commit(message: message)))
      result = try .make(value: Execute.parseText(reply: execute(git.getSha(ref: .head))))
    } else {
      result = nil
    }
    try Execute.checkStatus(reply: execute(git.detach(ref: initial)))
    try Execute.checkStatus(reply: execute(git.clean))
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
    git: Git,
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
    case .sysFile(let sysFile): return try Id(sysFile)
      .map(git.root.makeResolve(path:))
      .map(resolveAbsolute)
      .map(Files.ReadFile.init(file:))
      .map(readFile)
      .map(String.make(utf8:))
      .get()
    case .gitFile(let file): return try Id(file)
      .map(git.cat(file:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .get()
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
}
