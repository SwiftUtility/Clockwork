import Foundation
import Facility
import FacilityQueries
import FacilityAutomates
public struct Configurator {
  public var decodeYaml: Try.Reply<DecodeYaml>
  public var resolveAbsolutePath: Try.Reply<ResolveAbsolutePath>
  public var readFile: Try.Reply<ReadFile>
  public var gitHandleFileList: Try.Reply<Git.HandleFileList>
  public var gitHandleLine: Try.Reply<Git.HandleLine>
  public var gitHandleCat: Try.Reply<Git.HandleCat>
  public var gitHandleVoid: Try.Reply<Git.HandleVoid>
  public var logMessage: Act.Reply<LogMessage>
  public var dialect: AnyCodable.Dialect
  public init(
    decodeYaml: @escaping Try.Reply<DecodeYaml>,
    resolveAbsolutePath: @escaping Try.Reply<ResolveAbsolutePath>,
    readFile: @escaping Try.Reply<ReadFile>,
    gitHandleFileList: @escaping Try.Reply<Git.HandleFileList>,
    gitHandleLine: @escaping Try.Reply<Git.HandleLine>,
    gitHandleCat: @escaping Try.Reply<Git.HandleCat>,
    gitHandleVoid: @escaping Try.Reply<Git.HandleVoid>,
    logMessage: @escaping Act.Reply<LogMessage>,
    dialect: AnyCodable.Dialect = .json
  ) {
    self.decodeYaml = decodeYaml
    self.resolveAbsolutePath = resolveAbsolutePath
    self.readFile = readFile
    self.gitHandleFileList = gitHandleFileList
    self.gitHandleLine = gitHandleLine
    self.gitHandleCat = gitHandleCat
    self.gitHandleVoid = gitHandleVoid
    self.logMessage = logMessage
    self.dialect = dialect
  }
  public func resolveConfiguration(
    query: ResolveConfiguration
  ) throws -> ResolveConfiguration.Reply {
    let profile = try Id(query.profile)
      .map(ResolveAbsolutePath.make(path:))
      .map(resolveAbsolutePath)
      .get()
    let dir = profile.path
      .components(separatedBy: "/")
      .dropLast()
      .joined(separator: "/")
    var git = try Id(dir)
      .map(Path.Absolute.init(path:))
      .map(Git.HandleLine.make(resolveTopLevel:))
      .map(gitHandleLine)
      .map(Path.Absolute.init(path:))
      .map(Git.init(root:))
      .get()
    do { try gitHandleVoid(git.updateLfs) } catch { git.lfs = false }
    try gitHandleVoid(git.fetch)
    var configuration = try Configuration(
      git: git,
      env: query.env,
      profile: resolveProfile(query: .init(git: git, file: .init(
        ref: .head,
        path: .init(path: profile.path.dropPrefix("\(git.root.path)/"))
      )))
    )
    try enrich(cfg: &configuration)
    return configuration
  }
  public func resolveProfile(
    query: ResolveProfile
  ) throws -> ResolveProfile.Reply {
    let yaml = try dialect.read(Yaml.Profile.self, from: parse(git: query.git, yaml: query.file))
    var result = try Configuration.Profile.make(file: query.file, yaml: yaml)
    result.context = try yaml.context
      .map(Path.Relative.init(path:))
      .reduce(query.file.ref, Git.File.init(ref:path:))
      .reduce(query.git, parse(git:yaml:))
    result.templates = try yaml.templates
      .map(Path.Relative.init(path:))
      .reduce(query.file.ref, Git.Dir.init(ref:path:))
      .reduce(query.git, parse(git:templates:))
      .or([:])
    return result
  }
  public func resolveFileApproval(
    query: ResolveFileApproval
  ) throws -> ResolveFileApproval.Reply { try query.profile
    .flatMap(\.fileApproval)
    .flatMapNil(query.cfg.profile.fileApproval)
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([String: Yaml.Criteria].self, dialect.read(_:from:))?
    .mapValues(Criteria.init(yaml:))
  }
  public func resolveFileRules(
    query: ResolveFileRules
  ) throws -> ResolveFileRules.Reply { try query.profile
    .flatMap(\.fileRules)
    .flatMapNil(query.cfg.profile.fileRules)
    .reduce(query.cfg.git, parse(git:yaml:))
    .reduce([Yaml.FileRule].self, dialect.read(_:from:))
    .or { throw Thrown("FileRules not configured") }
    .map(FileRule.init(yaml:))
  }
  public func resolveAwardApproval(
    query: ResolveAwardApproval
  ) throws -> ResolveAwardApproval.Reply {
    var result = try query.cfg.awardApproval
      .reduce(query.cfg.git, parse(git:yaml:))
      .reduce(Yaml.AwardApproval.self, dialect.read(_:from:))
      .map(AwardApproval.make(yaml:))
      .or { throw Thrown("AwardApproval not configured") }
    result.consider(
      activeUsers: try query.cfg.assets
        .flatMap(\.activeUsers)
        .reduce(query.cfg.git, parse(git:yaml:))
        .reduce([String: Bool].self, dialect.read(_:from:))
        .or([:])
    )
    return result
  }
  public func resolveGitlab(
    query: ResolveGitlab
  ) throws -> ResolveGitlab.Reply {
    var gitlab = try Gitlab(cfg: query.cfg)
    gitlab.token = try? parse(env: query.cfg.env, token: ?!gitlab.botToken)
    return gitlab
  }
}
extension Configurator {
  func parse(git: Git, yaml: Git.File) throws -> AnyCodable { try Id
    .make(yaml)
    .map(git.cat(file:))
    .map(gitHandleCat)
    .map(String.make(utf8:))
    .map(DecodeYaml.init(content:))
    .map(decodeYaml)
    .get()
  }
  func parse(
    env: [String: String],
    token: Configuration.Token
  ) throws -> String {
    switch token {
    case .value(let value): return value
    case .envVar(let envVar): return try env[envVar]
      .or { throw Thrown("No env \(envVar)") }
    case .envFile(let envFile): return try env[envFile]
      .map(Path.Absolute.init(path:))
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
    for file in try gitHandleFileList(git.listTreeTrackedFiles(dir: templates)) {
      let template = try file.dropPrefix("\(templates.path.path)/")
      result[template] = try Id(file)
        .map(Path.Relative.init(path:))
        .reduce(templates.ref, Git.File.init(ref:path:))
        .map(git.cat(file:))
        .map(gitHandleCat)
        .map(String.make(utf8:))
        .get()
    }
    return result
  }
  func enrich(cfg: inout Configuration) throws {
    let controls = try Id(cfg.profile.controls)
      .reduce(cfg.git, parse(git:yaml:))
      .reduce(Yaml.Controls.self, dialect.read(_:from:))
      .get()
    let sha = try gitHandleLine(cfg.git.getSha(ref: cfg.profile.controls.ref))
    logMessage(.init(message: "Controls: \(sha)"))
    cfg.forbiddenCommits = try controls.forbiddenCommits
      .or([])
      .map(Git.Sha.init(ref:))
    cfg.awardApproval = try controls.awardApproval
      .map(Path.Relative.init(path:))
      .reduce(cfg.profile.controls.ref, Git.File.init(ref:path:))
    cfg.requisites = try controls.requisites
      .or([:])
      .mapValues { try .make(ref: cfg.profile.controls.ref, yaml: $0) }
    cfg.review = try controls.review
      .map(Configuration.Review.make(yaml:))
    cfg.replication = try controls.replication
      .map(Configuration.Replication.make(yaml:))
    cfg.integration = try .make(yaml: controls)
    cfg.assets = try controls.assets
      .map(Configuration.Assets.make(yaml:))
    cfg.custom = try controls.custom
      .map(Path.Relative.init(path:))
      .reduce(cfg.profile.controls.ref, Git.File.init(ref:path:))
      .reduce(cfg.git, parse(git:yaml:))
    cfg.templates = try controls.templates
      .map(Path.Relative.init(path:))
      .reduce(cfg.profile.controls.ref, Git.Dir.init(ref:path:))
      .reduce(cfg.git, parse(git:templates:))
      .or([:])
    let slackHooks = try controls.slackHooks
      .or([:])
      .mapValues { try parse(env: cfg.env, token: Configuration.Token.init(yaml: $0)) }
    let notifications = try controls.notifications
      .map(Path.Relative.init(path:))
      .reduce(cfg.profile.controls.ref, Git.File.init(ref:path:))
      .reduce(cfg.git, parse(git:yaml:))
      .reduce(Yaml.Notifications.self, dialect.read(_:from:))
    for slackHook in notifications.flatMap(\.slackHooks).or([]) {
      guard cfg.templates[slackHook.template] != nil else {
        throw Thrown("No \(slackHook.template) in templates")
      }
      let notification = try Configuration.Notification.slackHook(.init(
        url: slackHooks[slackHook.hook]
          .or { throw Thrown("No \(slackHook.hook) in slackHooks") },
        template: slackHook.template,
        userName: slackHook.userName,
        channel: slackHook.channel,
        emojiIcon: slackHook.emojiIcon
      ))
      for event in slackHook.events {
        cfg.notifications[event] = cfg.notifications[event].or([]) + [notification]
      }
    }
  }
}
