import Foundation
import Facility
import FacilityQueries
import FacilityAutomates
public struct Configurator {
  let decodeYaml: Try.Reply<DecodeYaml>
  let resolveAbsolutePath: Try.Reply<ResolveAbsolutePath>
  let readFile: Try.Reply<ReadFile>
  let handleFileList: Try.Reply<Git.HandleFileList>
  let handleLine: Try.Reply<Git.HandleLine>
  let handleCat: Try.Reply<Git.HandleCat>
  let handleVoid: Try.Reply<Git.HandleVoid>
  let renderStencil: Try.Reply<RenderStencil>
  let writeData: Try.Reply<WriteData>
  let logMessage: Act.Reply<LogMessage>
  let printLine: Act.Of<String>.Go
  let dialect: AnyCodable.Dialect
  public init(
    decodeYaml: @escaping Try.Reply<DecodeYaml>,
    resolveAbsolutePath: @escaping Try.Reply<ResolveAbsolutePath>,
    readFile: @escaping Try.Reply<ReadFile>,
    handleFileList: @escaping Try.Reply<Git.HandleFileList>,
    handleLine: @escaping Try.Reply<Git.HandleLine>,
    handleCat: @escaping Try.Reply<Git.HandleCat>,
    handleVoid: @escaping Try.Reply<Git.HandleVoid>,
    renderStencil: @escaping Try.Reply<RenderStencil>,
    writeData: @escaping Try.Reply<WriteData>,
    logMessage: @escaping Act.Reply<LogMessage>,
    printLine: @escaping Act.Of<String>.Go,
    dialect: AnyCodable.Dialect
  ) {
    self.decodeYaml = decodeYaml
    self.resolveAbsolutePath = resolveAbsolutePath
    self.readFile = readFile
    self.handleFileList = handleFileList
    self.handleLine = handleLine
    self.handleCat = handleCat
    self.handleVoid = handleVoid
    self.renderStencil = renderStencil
    self.writeData = writeData
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
      .map(ResolveAbsolutePath.make(path:))
      .map(resolveAbsolutePath)
      .get()
    let repoPath = profilePath.value
      .components(separatedBy: "/")
      .dropLast()
      .joined(separator: "/")
    var git = try Id(repoPath)
      .map(Path.Absolute.init(value:))
      .map(Git.HandleLine.make(resolveTopLevel:))
      .map(handleLine)
      .map(Path.Absolute.init(value:))
      .reduce(verbose, Git.init(verbose:root:))
      .get()
    do { try handleVoid(git.updateLfs) } catch { git.lfs = false }
    try handleVoid(git.fetch)
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
    let sha = try handleLine(git.getSha(ref: profile.controls.ref))
    logMessage(.init(message: "Controls: \(sha)"))
    controls.stencilCustom = try yaml.stencilCustom
      .map(Path.Relative.init(value:))
      .reduce(profile.controls.ref, Git.File.init(ref:path:))
      .reduce(git, parse(git:yaml:))
    controls.stencilTemplates = try yaml.stencilTemplates
      .map(Path.Relative.init(value:))
      .reduce(profile.controls.ref, Git.Dir.init(ref:path:))
      .reduce(git, parse(git:templates:))
      .or([:])
    if let yaml = yaml.gitlabCi {
      controls.gitlabCi = GitlabCi.make(
        verbose: verbose,
        env: env,
        yaml: yaml,
        apiToken: GitlabCi.makeApiToken(env: env, yaml: yaml)
          .reduce(env, parse(env:token:)),
        pushToken: GitlabCi.makePushToken(env: env, yaml: yaml)
          .reduce(env, parse(env:token:))
      )
    }
    let communication = try Id(yaml.communication)
      .map(Path.Relative.init(value:))
      .reduce(profile.controls.ref, Git.File.init(ref:path:))
      .reduce(git, parse(git:yaml:))
      .reduce(Yaml.Controls.Communication.self, dialect.read(_:from:))
      .get()
    let hooks = try communication.slackHooks
      .mapValues { try parse(env: env, token: .init(yaml: $0)) }
    for yaml in communication.slackHookTextMessages.or([]) {
      guard controls.stencilTemplates[yaml.messageTemplate] != nil else {
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
    return .init(git: git, env: env, profile: profile, controls: controls)
  }
  public func resolveFlow(
    query: ResolveFlow
  ) throws -> ResolveFlow.Reply { try query.cfg.controls.flow
      .reduce(query.cfg.git, parse(git:yaml:))
      .reduce(Yaml.Controls.Flow.self, dialect.read(_:from:))
      .reduce(query.cfg.controls.mainatiners, Flow.make(mainatiners:yaml:))
      .or { throw Thrown("flow not configured") }
  }
  public func resolveProduction(
    query: ResolveProduction
  ) throws -> ResolveProduction.Reply { try query.cfg.controls.production
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce(Yaml.Controls.Production.self, dialect.read(_:from:))
    .reduce(query.cfg.controls.mainatiners, Production.make(mainatiners:yaml:))
    .or { throw Thrown("production not configured") }
  }
  public func resolveProductionBuilds(
    query: ResolveProductionBuilds
  ) throws -> ResolveProductionBuilds.Reply { try Id
    .make(Git.File(
      ref: .make(remote: query.production.builds.branch),
      path: query.production.builds.file
    ))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([Yaml.Controls.Production.Build].self, dialect.read(_:from:))
    .get()
  }
  public func resolveProductionVersions(
    query: ResolveProductionVersions
  ) throws -> ResolveProductionVersions.Reply { try Id
    .make(Git.File(
      ref: .make(remote: query.production.versions.branch),
      path: query.production.versions.file
    ))
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: String].self, dialect.read(_:from:))
    .get()
  }
  public func resolveProfile(
    query: ResolveProfile
  ) throws -> ResolveProfile.Reply {
    let yaml = try dialect.read(Yaml.Profile.self, from: parse(git: query.git, yaml: query.file))
    var result = try Configuration.Profile.make(profile: query.file, yaml: yaml)
    result.stencilTemplates = try yaml.stencilTemplates
      .map(Path.Relative.init(value:))
      .reduce(query.file.ref, Git.Dir.init(ref:path:))
      .reduce(query.git, parse(git:templates:))
      .or([:])
    return result
  }
  public func resolveCodeOwnage(
    query: ResolveCodeOwnage
  ) throws -> ResolveCodeOwnage.Reply { try query.profile.codeOwnage
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: Yaml.Criteria].self, dialect.read(_:from:))
    .or { throw Thrown("codeOwnage not configured") }
    .mapValues(Criteria.init(yaml:))
  }
  public func resolveFileTaboos(
    query: ResolveFileTaboos
  ) throws -> ResolveFileTaboos.Reply { try query.profile.fileTaboos
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([Yaml.Profile.FileTaboo].self, dialect.read(_:from:))
    .or { throw Thrown("fileTaboos not configured") }
    .map(FileTaboo.init(yaml:))
  }
  public func resolveAwardApproval(
    query: ResolveAwardApproval
  ) throws -> ResolveAwardApproval.Reply { try query.cfg.controls.awardApproval
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce(Yaml.Controls.AwardApproval.self, dialect.read(_:from:))
    .map(AwardApproval.make(yaml:))
    .or { throw Thrown("AwardApproval not configured") }
  }
  public func resolveAwardApprovalUserActivity(
    query: ResolveAwardApprovalUserActivity
  ) throws -> ResolveAwardApprovalUserActivity.Reply { try Id
    .make(query.awardApproval.userActivity.remote)
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: Bool].self, dialect.read(_:from:))
    .get()
  }
  public func persistVersions(
    query: PersistVersions
  ) throws -> PersistVersions.Reply {
    var versions = query.versions
    versions[query.product.name] = query.version
    let message = try renderStencil(.make(generator: query.cfg.generateVersionCommitMessage(
      asset: query.production.versions,
      product: query.product,
      version: query.version
    )))
    return try handleVoid(query.cfg.git.make(push: .init(
      url: query.pushUrl,
      branch: query.production.versions.branch,
      sha: persist(
        git: query.cfg.git,
        file: query.production.versions.file,
        branch: query.production.versions.branch,
        yaml: versions
          .map { "\($0.key): '\($0.value)'\n" }
          .sorted()
          .joined(),
        message: message
      ),
      force: false
    )))
  }
  public func persistBuilds(
    query: PersistBuilds
  ) throws -> PersistBuilds.Reply {
    let builds = query.builds + [query.build]
    let message = try renderStencil(.make(generator: query.cfg.generateBuildCommitMessage(
      asset: query.production.builds,
      build: query.build.build
    )))
    return try handleVoid(query.cfg.git.make(push: .init(
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
    )))
  }
  public func persistUserActivity(
    query: PersistUserActivity
  ) throws -> PersistUserActivity.Reply {
    var userActivity = query.userActivity
    userActivity[query.user] = query.active
    let message = try renderStencil(.make(generator: query.cfg.generateUserActivityCommitMessage(
      asset: query.awardApproval.userActivity,
      user: query.user,
      active: query.active
    )))
    return try handleVoid(query.cfg.git.make(push: .init(
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
    )))
  }
}
extension Configurator {
  func persist(
    git: Git,
    file: Path.Relative,
    branch: Git.Branch,
    yaml: String,
    message: String
  ) throws -> Git.Sha {
    let initial = try handleLine(git.getSha(ref: .head))
    try handleVoid(git.detach(to: .make(remote: branch)))
    try handleVoid(git.clean)
    try writeData(.init(path: "\(git.root.value)/\(file.value)", data: .init(yaml.utf8)))
    try handleVoid(git.addAll)
    try handleVoid(git.commit(message: message))
    let result = try Git.Sha(value: handleLine(git.getSha(ref: .head)))
    try handleVoid(git.detach(to: .make(sha: .init(value: initial))))
    return result
  }
  func parse(git: Git, yaml: Git.File) throws -> AnyCodable { try Id
    .make(yaml)
    .map(git.cat(file:))
    .map(handleCat)
    .map(String.make(utf8:))
    .map(DecodeYaml.init(content:))
    .map(decodeYaml)
    .get()
  }
  func parse(
    env: [String: String],
    token: Token
  ) throws -> String {
    switch token {
    case .value(let value): return value
    case .envVar(let envVar): return try env[envVar]
      .or { throw Thrown("No env \(envVar)") }
    case .envFile(let envFile): return try env[envFile]
      .map(Path.Absolute.init(value:))
      .map(ReadFile.init(file:))
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
    for file in try handleFileList(git.listTreeTrackedFiles(dir: templates)) {
      let template = try file.dropPrefix("\(templates.path.value)/")
      result[template] = try Id(file)
        .map(Path.Relative.init(value:))
        .reduce(templates.ref, Git.File.init(ref:path:))
        .map(git.cat(file:))
        .map(handleCat)
        .map(String.make(utf8:))
        .get()
    }
    return result
  }
  func makeYaml(build: Yaml.Controls.Production.Build) -> [String] {
    ["- build: '\(build.build)'\n", "  sha: '\(build.sha)'\n"]
    + build.branch.map { "  branch: '\($0)'\n" }.makeArray()
    + build.tag.map { "  tag: '\($0)'\n" }.makeArray()
  }
}
