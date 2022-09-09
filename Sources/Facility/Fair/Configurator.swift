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
  let writeStdout: Act.Of<String>.Go
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
    writeStdout: @escaping Act.Of<String>.Go,
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
    self.writeStdout = writeStdout
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
      signals: profile.signals
        .reduce(git, parse(git:yaml:))
        .reduce([String: [Yaml.Signal]].self, dialect.read(_:from:))
        .get([:])
        .mapValues { try $0.map(Configuration.Signal.make(yaml:)) },
      gitlabCi: .init(try .make(
        verbose: verbose,
        env: env,
        gitlabCi: profile.gitlabCi,
        job: GitlabCi.getCurrentJob(verbose: verbose, env: env)
          .map(execute)
          .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:)),
        botLogin: parse(env: env, secret: profile.gitlabCi.botLogin),
        apiToken: GitlabCi.isPretected(env: env)
          .map { try parse(env: env, secret: profile.gitlabCi.apiToken) },
        pushToken: GitlabCi.isPretected(env: env)
          .map { try parse(env: env, secret: profile.gitlabCi.pushToken) }
      )),
      slackToken: GitlabCi.isPretected(env: env)
        .map { try parse(env: env, secret: profile.slackToken) }
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
//  public func resolveAwardApproval(
//    query: Configuration.ResolveAwardApproval
//  ) throws -> Configuration.ResolveAwardApproval.Reply { try query.cfg.profile.awardApproval
//    .reduce(query.cfg.git, parse(git:yaml:))
//    .reduce(Yaml.AwardApproval.self, dialect.read(_:from:))
//    .map(AwardApproval.make(yaml:))
//    .get()
//  }
//  public func resolveUserActivity(
//    query: Configuration.ResolveUserActivity
//  ) throws -> Configuration.ResolveUserActivity.Reply { try query.cfg.profile.userActivity
//    .map(Git.File.make(asset:))
//    .reduce(query.cfg.git, parse(git:yaml:))
//    .reduce([String: Bool].self, dialect.read(_:from:))
//    .get()
//  }
  public func resolveForbiddenCommits(
    query: Configuration.ResolveForbiddenCommits
  ) throws -> Configuration.ResolveForbiddenCommits.Reply { try query.cfg.profile.forbiddenCommits
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String].self, dialect.read(_:from:))
    .get()
    .map(Git.Sha.init(value:))
  }
  public func resolveReviewQueue(
    query: Fusion.Queue.Resolve
  ) throws -> Fusion.Queue.Resolve.Reply { try query.cfg.profile.reviewQueue
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
    let asset = try query.cfg.profile.userActivity.get()
    let message = try generate(query.cfg.createUserActivityCommitMessage(
      asset: asset,
      user: query.user,
      active: query.active
    ))
    try Execute.checkStatus(reply: execute(query.cfg.git.push(
      url: query.pushUrl,
      branch: asset.branch,
      sha: persist(
        git: query.cfg.git,
        file: asset.file,
        branch: asset.branch,
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
    let asset = try query.cfg.profile.reviewQueue.get()
    let message = try generate(query.cfg.createReviewQueueCommitMessage(
      asset: asset,
      review: query.review,
      queued: query.queued
    ))
    try Execute.checkStatus(reply: execute(query.cfg.git.push(
      url: query.pushUrl,
      branch: asset.branch,
      sha: persist(
        git: query.cfg.git,
        file: asset.file,
        branch: asset.branch,
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
