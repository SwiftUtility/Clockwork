import Foundation
import Facility
public struct Configuration {
  public var verbose: Bool
  public var git: Git
  public var env: [String: String]
  public var profile: Profile
  public var templates: [String: String] = [:]
  public var context: AnyCodable?
  public var communication: Communication = .init()
  public var gitlabCi: Lossy<GitlabCi> = .error(Thrown("gitlabCi not configured"))
  public init(
    verbose: Bool,
    git: Git,
    env: [String : String],
    profile: Profile
  ) {
    self.verbose = verbose
    self.git = git
    self.env = env
    self.profile = profile
  }
  public func get(env key: String) throws -> String {
    try env[key].get { throw Thrown("No \(key) in environment") }
  }
  public struct Profile {
    public var profile: Git.File
    public var gitlabCi: Git.File
    public var communication: Git.File
    public var awardApproval: Lossy<Git.File>
    public var context: Git.File?
    public var codeOwnage: Lossy<Git.File>
    public var fileTaboos: Lossy<Git.File>
    public var cocoapods: Lossy<Git.File>
    public var templates: Git.Dir?
    public var production: Lossy<Git.File>
    public var requisition: Lossy<Git.File>
    public var fusion: Lossy<Git.File>
    public var forbiddenCommits: Lossy<Asset>
    public var userActivity: Lossy<Asset>
    public var reviewQueue: Lossy<Asset>
    public var trigger: Trigger
    public var obsolescence: Lossy<Criteria>
    public static func make(
      profile: Git.File,
      yaml: Yaml.Profile
    ) throws -> Self { try .init(
      profile: profile,
      gitlabCi: .make(preset: yaml.gitlabCi),
      communication: .make(preset: yaml.communication),
      awardApproval: yaml.awardApproval
        .map(Git.File.make(preset:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("awardApproval not configured"))),
      context: yaml.context
        .map(Git.File.make(preset:)),
      codeOwnage: yaml.codeOwnage
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("codeOwnage not configured"))),
      fileTaboos: yaml.fileTaboos
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("fileTaboos not configured"))),
      cocoapods: yaml.cocoapods
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("cocoapods not configured"))),
      templates: yaml.templates
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.Dir.init(ref:path:)),
      production: yaml.production
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("production not configured"))),
      requisition: yaml.requisition
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("requisition not configured"))),
      fusion: yaml.fusion
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("fusion not configured"))),
      forbiddenCommits: yaml.forbiddenCommits
        .map(Asset.make(yaml:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("forbiddenCommits not configured"))),
      userActivity: yaml.userActivity
        .map(Asset.make(yaml:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("userActivity not configured"))),
      reviewQueue: yaml.reviewQueue
        .map(Asset.make(yaml:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("reviewQueue not configured"))),
      trigger: .init(
        job: yaml.trigger.job,
        name: yaml.trigger.name,
        profile: yaml.trigger.profile,
        pipeline: yaml.trigger.pipeline
      ),
      obsolescence: yaml.obsolescence
        .map(Criteria.init(yaml:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("obsolescence not configured")))
    )}
    public var sanityFiles: [String] {
      [
        profile,
        try? codeOwnage.get(),
        try? fileTaboos.get(),
        try? production.get(),
        try? requisition.get(),
        try? fusion.get(),
      ].compactMap(\.?.path.value)
    }
  }
  public struct Trigger {
    public var job: String
    public var name: String
    public var profile: String
    public var pipeline: String
  }
  public struct Asset {
    public var file: Files.Relative
    public var branch: Git.Branch
    public var createCommitMessage: Template
    public static func make(
      yaml: Yaml.Asset
    ) throws -> Self { try .init(
      file: .init(value: yaml.path),
      branch: .init(name: yaml.branch),
      createCommitMessage: .make(yaml: yaml.createCommitMessage)
    )}
  }
  public enum Template {
    case name(String)
    case value(String)
    public static func make(yaml: Yaml.Template) throws -> Self {
      guard [yaml.name, yaml.value].compactMap({$0}).count < 2
      else { throw Thrown("Multiple values in template") }
      if let value = yaml.name { return .name(value) }
      else if let value = yaml.value { return .value(value) }
      else { throw Thrown("No values in template") }
    }
  }
  public enum Secret {
    case value(String)
    case envVar(String)
    case envFile(String)
    public static func make(yaml: Yaml.Secret) throws -> Self {
      guard [yaml.value, yaml.envVar, yaml.envFile].compactMap({$0}).count < 2
      else { throw Thrown("Multiple values in secret") }
      if let value = yaml.value { return .value(value) }
      else if let envVar = yaml.envVar { return .envVar(envVar) }
      else if let envFile = yaml.envFile { return .envFile(envFile) }
      else { throw Thrown("No values in secret") }
    }
  }
  public struct ResolveProfile: Query {
    public var git: Git
    public var file: Git.File
    public init(git: Git, file: Git.File) {
      self.git = git
      self.file = file
    }
    public typealias Reply = Configuration.Profile
  }
  public struct ResolveSecret: Query {
    public var cfg: Configuration
    public var secret: Secret
    public init(cfg: Configuration, secret: Secret) {
      self.cfg = cfg
      self.secret = secret
    }
    public typealias Reply = String
  }
  public struct ResolveCodeOwnage: Query {
    public var cfg: Configuration
    public var profile: Configuration.Profile
    public init(cfg: Configuration, profile: Configuration.Profile) {
      self.cfg = cfg
      self.profile = profile
    }
    public typealias Reply = [String: Criteria]
  }
  public struct ResolveFileTaboos: Query {
    public var cfg: Configuration
    public var profile: Configuration.Profile
    public init(cfg: Configuration, profile: Configuration.Profile) {
      self.cfg = cfg
      self.profile = profile
    }
    public typealias Reply = [FileTaboo]
  }
  public struct ResolveCocoapods: Query {
    public var cfg: Configuration
    public var profile: Configuration.Profile
    public init(cfg: Configuration, profile: Configuration.Profile) {
      self.cfg = cfg
      self.profile = profile
    }
    public typealias Reply = Cocoapods
  }
  public struct PersistCocoapods: Query {
    public var cfg: Configuration
    public var cocoapods: Cocoapods
    public init(cfg: Configuration, cocoapods: Cocoapods) {
      self.cfg = cfg
      self.cocoapods = cocoapods
    }
    public typealias Reply = Void
  }
  public struct ResolveAwardApproval: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = AwardApproval
  }
  public struct ResolveUserActivity: Query {
    public var cfg: Configuration
    public var awardApproval: AwardApproval
    public init(cfg: Configuration, awardApproval: AwardApproval) {
      self.cfg = cfg
      self.awardApproval = awardApproval
    }
    public typealias Reply = [String: Bool]
  }
  public struct ResolveRequisition: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = Requisition
  }
  public struct ResolveFusion: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = Fusion
  }
  public struct ResolveProduction: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = Production
  }
  public struct ResolveProductionBuilds: Query {
    public var cfg: Configuration
    public var production: Production
    public init(cfg: Configuration, production: Production) {
      self.cfg = cfg
      self.production = production
    }
    public typealias Reply = [Production.Build]
  }
  public struct ResolveProductionVersions: Query {
    public var cfg: Configuration
    public var production: Production
    public init(cfg: Configuration, production: Production) {
      self.cfg = cfg
      self.production = production
    }
    public typealias Reply = [String: String]
  }
  public struct ResolveForbiddenCommits: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = [Git.Sha]
  }
  public struct PersistBuilds: Query {
    public var cfg: Configuration
    public var pushUrl: String
    public var production: Production
    public var builds: [Production.Build]
    public var build: Production.Build
    public init(
      cfg: Configuration,
      pushUrl: String,
      production: Production,
      builds: [Production.Build],
      build: Production.Build
    ) {
      self.cfg = cfg
      self.pushUrl = pushUrl
      self.production = production
      self.builds = builds
      self.build = build
    }
    public typealias Reply = Void
  }
  public struct PersistVersions: Query {
    public var cfg: Configuration
    public var pushUrl: String
    public var production: Production
    public var versions: [String: String]
    public var product: Production.Product
    public var version: String
    public init(
      cfg: Configuration,
      pushUrl: String,
      production: Production,
      versions: [String: String],
      product: Production.Product,
      version: String
    ) {
      self.cfg = cfg
      self.pushUrl = pushUrl
      self.production = production
      self.versions = versions
      self.product = product
      self.version = version
    }
    public typealias Reply = Void
  }
  public struct PersistUserActivity: Query {
    public var cfg: Configuration
    public var pushUrl: String
    public var awardApproval: AwardApproval
    public var userActivity: [String: Bool]
    public var user: String
    public var active: Bool
    public init(
      cfg: Configuration,
      pushUrl: String,
      awardApproval: AwardApproval,
      userActivity: [String: Bool],
      user: String,
      active: Bool
    ) {
      self.cfg = cfg
      self.pushUrl = pushUrl
      self.awardApproval = awardApproval
      self.userActivity = userActivity
      self.user = user
      self.active = active
    }
    public typealias Reply = Void
  }
}
