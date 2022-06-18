import Foundation
import Facility
import FacilityPure
public struct Configurator {
  let execute: Try.Reply<Execute>
  let decodeYaml: Try.Reply<Yaml.Decode>
  let resolveAbsolute: Try.Reply<Files.ResolveAbsolute>
  let readFile: Try.Reply<Files.ReadFile>
  let generate: Try.Reply<Generate>
  let writeFile: Try.Reply<Files.WriteFile>
  let logMessage: Act.Reply<LogMessage>
  let printLine: Act.Of<String>.Go
  let dialect: AnyCodable.Dialect
  public init(
    execute: @escaping Try.Reply<Execute>,
    decodeYaml: @escaping Try.Reply<Yaml.Decode>,
    resolveAbsolute: @escaping Try.Reply<Files.ResolveAbsolute>,
    readFile: @escaping Try.Reply<Files.ReadFile>,
    generate: @escaping Try.Reply<Generate>,
    writeFile: @escaping Try.Reply<Files.WriteFile>,
    logMessage: @escaping Act.Reply<LogMessage>,
    printLine: @escaping Act.Of<String>.Go,
    dialect: AnyCodable.Dialect
  ) {
    self.execute = execute
    self.decodeYaml = decodeYaml
    self.resolveAbsolute = resolveAbsolute
    self.readFile = readFile
    self.generate = generate
    self.writeFile = writeFile
    self.logMessage = logMessage
    self.printLine = printLine
    self.dialect = dialect
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
      .map(Execute.successText(reply:))
      .map(Files.Absolute.init(value:))
      .reduce(verbose, Git.init(verbose:root:))
      .get()
    do { _ = try execute(git.updateLfs) } catch { git.lfs = false }
    _ = try execute(git.fetch)
    let profile = try resolveProfile(query: .init(git: git, file: .init(
      ref: .head,
      path: .init(value: profilePath.value.dropPrefix("\(git.root.value)/"))
    )))
    let yaml = try Id(profile.controls)
      .reduce(git, parse(git:yaml:))
      .reduce(Yaml.Controls.self, dialect.read(_:from:))
      .get()
    var controls = try Configuration.Controls.make(
      ref: profile.controls.ref,
      env: env,
      yaml: yaml
    )
    _ = try Id(profile.controls.ref)
      .map(git.getSha(ref:))
      .map(execute)
      .map(Execute.successText(reply:))
      .map { "Controls: " + $0 }
      .map(LogMessage.init(message:))
      .map(logMessage)
    controls.context = try yaml.context
      .map(Files.Relative.init(value:))
      .reduce(profile.controls.ref, Git.File.init(ref:path:))
      .reduce(git, parse(git:yaml:))
    controls.templates = try yaml.templates
      .map(Files.Relative.init(value:))
      .reduce(profile.controls.ref, Git.Dir.init(ref:path:))
      .reduce(git, parse(git:templates:))
      .or([:])
    if let yaml = yaml.gitlabCi {
      controls.gitlabCi = GitlabCi.make(
        verbose: verbose,
        env: env,
        yaml: yaml,
        apiToken: GitlabCi.makeApiToken(env: env, yaml: yaml)
          .reduce(env, parse(env:secret:)),
        pushToken: GitlabCi.makePushToken(env: env, yaml: yaml)
          .reduce(env, parse(env:secret:))
      )
    }
    let communication = try Id(yaml.communication)
      .map(Files.Relative.init(value:))
      .reduce(profile.controls.ref, Git.File.init(ref:path:))
      .reduce(git, parse(git:yaml:))
      .reduce(Yaml.Controls.Communication.self, dialect.read(_:from:))
      .get()
    let hooks = try communication.slackHooks
      .mapValues { try parse(env: env, secret: .init(yaml: $0)) }
    for yaml in communication.slackHookTextMessages.or([]) {
      guard controls.templates[yaml.messageTemplate] != nil else {
        throw Thrown("No template \(yaml.messageTemplate)")
      }
      let communication = try Communication.slackHookTextMessage(.init(
        url: hooks[yaml.hook]
          .or { throw Thrown("No \(yaml.hook) in slackHooks") },
        yaml: yaml
      ))
      for event in yaml.events {
        controls.communication[event] = controls.communication[event].or([]) + [communication]
      }
    }
    return .init(verbose: verbose, git: git, env: env, profile: profile, controls: controls)
  }
  public func resolveRequisition(
    query: Configuration.ResolveRequisition
  ) throws -> Configuration.ResolveRequisition.Reply { try query.cfg.controls.requisition
      .reduce(query.cfg.git, parse(git:yaml:))
      .reduce([String: Yaml.Controls.Requisition].self, dialect.read(_:from:))
      .map { yaml in try Requisition.make(
        verbose: query.cfg.verbose,
        ref: query.cfg.profile.controls.ref,
        yaml: yaml
      )}
      .or { throw Thrown("requisition not configured") }
  }
  public func resolveFlow(
    query: Configuration.ResolveFlow
  ) throws -> Configuration.ResolveFlow.Reply { try query.cfg.controls.flow
      .reduce(query.cfg.git, parse(git:yaml:))
      .reduce(Yaml.Controls.Flow.self, dialect.read(_:from:))
      .reduce(query.cfg.controls.mainatiners, Flow.make(mainatiners:yaml:))
      .or { throw Thrown("flow not configured") }
  }
  public func resolveProduction(
    query: Configuration.ResolveProduction
  ) throws -> Configuration.ResolveProduction.Reply { try query.cfg.controls.production
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce(Yaml.Controls.Production.self, dialect.read(_:from:))
    .reduce(query.cfg.controls.mainatiners, Production.make(mainatiners:yaml:))
    .or { throw Thrown("production not configured") }
  }
  public func resolveProductionBuilds(
    query: Configuration.ResolveProductionBuilds
  ) throws -> Configuration.ResolveProductionBuilds.Reply { try Id(query.production.builds)
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([Yaml.Controls.Production.Build].self, dialect.read(_:from:))
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
  ) throws -> Configuration.ResolveProfile.Reply {
    let yaml = try dialect.read(Yaml.Profile.self, from: parse(git: query.git, yaml: query.file))
    var result = try Configuration.Profile.make(profile: query.file, yaml: yaml)
    result.templates = try yaml.templates
      .map(Files.Relative.init(value:))
      .reduce(query.file.ref, Git.Dir.init(ref:path:))
      .reduce(query.git, parse(git:templates:))
      .or([:])
    return result
  }
  public func resolveCodeOwnage(
    query: Configuration.ResolveCodeOwnage
  ) throws -> Configuration.ResolveCodeOwnage.Reply { try query.profile.codeOwnage
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: Yaml.Criteria].self, dialect.read(_:from:))
    .or { throw Thrown("codeOwnage not configured") }
    .mapValues(Criteria.init(yaml:))
  }
  public func resolveFileTaboos(
    query: Configuration.ResolveFileTaboos
  ) throws -> Configuration.ResolveFileTaboos.Reply { try query.profile.fileTaboos
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([Yaml.Profile.FileTaboo].self, dialect.read(_:from:))
    .or { throw Thrown("fileTaboos not configured") }
    .map(FileTaboo.init(yaml:))
  }
  public func resolveAwardApproval(
    query: Configuration.ResolveAwardApproval
  ) throws -> Configuration.ResolveAwardApproval.Reply { try query.cfg.controls.awardApproval
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce(Yaml.Controls.AwardApproval.self, dialect.read(_:from:))
    .map(AwardApproval.make(yaml:))
    .or { throw Thrown("AwardApproval not configured") }
  }
  public func resolveUserActivity(
    query: Configuration.ResolveUserActivity
  ) throws -> Configuration.ResolveUserActivity.Reply { try Id(query.awardApproval.userActivity)
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: Bool].self, dialect.read(_:from:))
    .get()
  }
  public func resolveForbiddenCommits(
    query: Configuration.ResolveForbiddenCommits
  ) throws -> Configuration.ResolveForbiddenCommits.Reply { try query.cfg.controls.forbiddenCommits
    .map(Git.File.make(asset:))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String].self, dialect.read(_:from:))
    .or([])
    .map(Git.Sha.init(value:))
  }
  public func persistVersions(
    query: Configuration.PersistVersions
  ) throws -> Configuration.PersistVersions.Reply {
    var versions = query.versions
    versions[query.product.name] = query.version
    let message = try generate(query.cfg.generateVersionCommitMessage(
      asset: query.production.versions,
      product: query.product,
      version: query.version
    ))
    _ = try execute(query.cfg.git.push(
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
    ))
  }
  public func persistBuilds(
    query: Configuration.PersistBuilds
  ) throws -> Configuration.PersistBuilds.Reply {
    let builds = query.builds + [query.build]
    let message = try generate(query.cfg.generateBuildCommitMessage(
      asset: query.production.builds,
      build: query.build.value
    ))
    _ = try execute(query.cfg.git.push(
      url: query.pushUrl,
      branch: query.production.builds.branch,
      sha: persist(
        git: query.cfg.git,
        file: query.production.builds.file,
        branch: query.production.builds.branch,
        yaml: query.production.maxBuildsCount
          .map(builds.suffix(_:))
          .or(builds)
          .flatMap(makeYaml(build:))
          .joined(),
        message: message
      ),
      force: false
    ))
  }
  public func persistUserActivity(
    query: Configuration.PersistUserActivity
  ) throws -> Configuration.PersistUserActivity.Reply {
    var userActivity = query.userActivity
    userActivity[query.user] = query.active
    let message = try generate(query.cfg.generateUserActivityCommitMessage(
      asset: query.awardApproval.userActivity,
      user: query.user,
      active: query.active
    ))
    _ = try execute(query.cfg.git.push(
      url: query.pushUrl,
      branch: query.awardApproval.userActivity.branch,
      sha: persist(
        git: query.cfg.git,
        file: query.awardApproval.userActivity.file,
        branch: query.awardApproval.userActivity.branch,
        yaml: userActivity
          .map { "'\($0.key)': \($0.value)\n" }
          .sorted()
          .joined(),
        message: message
      ),
      force: false
    ))
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
      .map(Execute.successText(reply:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    _ = try execute(git.detach(ref: .make(remote: branch)))
    _ = try execute(git.clean)
    try writeFile(.init(
      file: .init(value: "\(git.root.value)/\(file.value)"),
      data: .init(yaml.utf8)
    ))
    _ = try execute(git.addAll)
    _ = try execute(git.commit(message: message))
    let result = try Id(.head)
      .map(git.getSha(ref:))
      .map(execute)
      .map(Execute.successText(reply:))
      .map(Git.Sha.init(value:))
      .get()
    _ = try execute(git.detach(ref: initial))
    return result
  }
  func parse(git: Git, yaml: Git.File) throws -> AnyCodable { try Id
    .make(yaml)
    .map(git.cat(file:))
    .map(execute)
    .map(Execute.successText(reply:))
    .map(Yaml.Decode.init(content:))
    .map(decodeYaml)
    .get()
  }
  func parse(
    env: [String: String],
    secret: Secret
  ) throws -> String {
    switch secret {
    case .value(let value): return value
    case .envVar(let envVar): return try env[envVar]
      .or { throw Thrown("No env \(envVar)") }
    case .envFile(let envFile): return try env[envFile]
      .map(Files.Absolute.init(value:))
      .map(Files.ReadFile.init(file:))
      .map(readFile)
      .map(String.make(utf8:))
      .or { throw Thrown("No env \(envFile)") }
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
      .map(Execute.successLines(reply:))
      .get()
      .filter { !$0.isEmpty }
    for file in files {
      let template = try file.dropPrefix("\(templates.path.value)/")
      result[template] = try Id(file)
        .map(Files.Relative.init(value:))
        .reduce(templates.ref, Git.File.init(ref:path:))
        .map(git.cat(file:))
        .map(execute)
        .map(Execute.successText(reply:))
        .get()
    }
    return result
  }
  func makeYaml(build: Production.Build) -> [String] {
    ["- build: '\(build.value)'\n", "  sha: '\(build.sha)'\n"]
    + build.branch.map { "  branch: '\($0)'\n" }.makeArray()
    + build.tag.map { "  tag: '\($0)'\n" }.makeArray()
  }
}
