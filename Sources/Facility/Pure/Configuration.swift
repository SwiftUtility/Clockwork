import Foundation
import Facility
public struct Configuration {
  public var verbose: Bool
  public var git: Git
  public var env: [String: String]
  public var profile: Profile
  public var controls: Controls
  public init(
    verbose: Bool,
    git: Git,
    env: [String : String],
    profile: Profile,
    controls: Controls
  ) {
    self.verbose = verbose
    self.git = git
    self.env = env
    self.profile = profile
    self.controls = controls
  }
  public func get(env key: String) throws -> String {
    try env[key].get { throw Thrown("No \(key) in environment") }
  }
  public struct Profile {
    public var profile: Git.File
    public var controls: Git.File
    public var codeOwnage: Git.File?
    public var fileTaboos: Git.File?
    public var obsolescence: Lossy<Criteria>
    public var templates: [String: String] = [:]
    public var renderBuild: Lossy<Template>
    public var renderVersions: Lossy<Template>
    public var renderIntegrationTargets: Lossy<Template>
    public static func make(
      profile: Git.File,
      yaml: Yaml.Profile
    ) throws -> Self { try .init(
      profile: profile,
      controls: .init(
        ref: .make(remote: .init(name: yaml.controls.branch)),
        path: .init(value: yaml.controls.path)
      ),
      codeOwnage: yaml.codeOwnage
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:)),
      fileTaboos: yaml.fileTaboos
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:)),
      obsolescence: yaml.obsolescence
        .map(Criteria.init(yaml:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("obsolescence not configured"))),
      renderBuild: yaml.renderBuild
        .map(Template.make(yaml:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("renderReviewBuild not configured"))),
      renderVersions: yaml.renderVersions
        .map(Template.make(yaml:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("renderVersions not configured"))),
      renderIntegrationTargets: yaml.renderIntegrationTargets
        .map(Template.make(yaml:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("renderIntegration not configured")))
    )}
    public var sanityFiles: [String] {
      [profile, codeOwnage, fileTaboos].compactMap(\.?.path.value)
    }
  }
  public struct Controls {
    public var mainatiners: Set<String>
    public var awardApproval: Git.File?
    public var production: Git.File?
    public var requisition: Git.File?
    public var fusion: Git.File?
    public var forbiddenCommits: Asset?
    public var templates: [String: String] = [:]
    public var context: AnyCodable?
    public var communication: [String: [Communication]] = [:]
    public var gitlabCi: Lossy<GitlabCi> = .error(Thrown("gitlabCi not configured"))
    public static func make(
      ref: Git.Ref,
      env: [String: String],
      yaml: Yaml.Controls
    ) throws -> Self { try .init(
      mainatiners: .init(yaml.mainatiners.get([])),
      awardApproval: yaml.awardApproval
        .map(Files.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      production: yaml.production
        .map(Files.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      requisition: yaml.requisition
        .map(Files.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      fusion: yaml.fusion
        .map(Files.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      forbiddenCommits: yaml.forbiddenCommits
        .map(Asset.make(yaml:))
    )}
  }
  public struct Asset {
    public var file: Files.Relative
    public var branch: Git.Branch
    public var commitMessage: Template?
    public static func make(
      yaml: Yaml.Asset
    ) throws -> Self { try .init(
      file: .init(value: yaml.path),
      branch: .init(name: yaml.branch),
      commitMessage: yaml.commitMessage
        .map(Template.make(yaml:))
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
      else { throw Thrown("No value in template") }
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
      else { throw Thrown("No value in secret") }
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
