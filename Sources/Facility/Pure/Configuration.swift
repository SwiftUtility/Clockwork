import Foundation
import Facility
public struct Configuration {
  public var verbose: Bool
  public var git: Git
  public var env: [String: String]
  public var profile: Profile
  public var templates: [String: String]
  public var context: AnyCodable?
  public var signals: [String: [Signal]]
  public var gitlabCi: Lossy<GitlabCi>
  public var slackToken: Lossy<String>
  public static func make(
    verbose: Bool,
    git: Git,
    env: [String : String],
    profile: Configuration.Profile,
    templates: [String : String],
    context: AnyCodable? = nil,
    signals: [String : [Configuration.Signal]],
    gitlabCi: Lossy<GitlabCi>,
    slackToken: Lossy<String>
  ) -> Self { .init(
    verbose: verbose,
    git: git,
    env: env,
    profile: profile,
    templates: templates,
    context: context,
    signals: signals,
    gitlabCi: gitlabCi,
    slackToken: slackToken
  )}
  public struct Profile {
    public var profile: Git.File
    public var gitlabCi: GitlabCi
    public var slackToken: Secret
    public var signals: Git.File?
    public var context: Git.File?
    public var templates: Git.Dir?
    public var fusion: Lossy<Git.File>
    public var codeOwnage: Lossy<Git.File>
    public var fileTaboos: Lossy<Git.File>
    public var cocoapods: Lossy<Git.File>
    public var production: Lossy<Git.File>
    public var requisition: Lossy<Git.File>
    public static func make(
      profile: Git.File,
      yaml: Yaml.Profile
    ) throws -> Self { try .init(
      profile: profile,
      gitlabCi: .make(yaml: yaml.gitlabCi),
      slackToken: .make(yaml: yaml.slackToken),
      signals: yaml.signals
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:)),
      context: yaml.context
        .map(Git.File.make(preset:)),
      templates: yaml.templates
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.Dir.init(ref:path:)),
      fusion: yaml.fusion
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("fusion not configured"))),
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
      production: yaml.production
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("production not configured"))),
      requisition: yaml.requisition
        .map(Files.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("requisition not configured")))
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
    public struct GitlabCi {
      public var botLogin: Secret
      public var apiToken: Secret
      public var pushToken: Secret
      public var triggerJobId: String
      public var triggerJobName: String
      public var triggerProfile: String
      public var triggerPipeline: String
      public static func make(
        yaml: Yaml.GitlabCi
      ) throws -> Self { try .init(
        botLogin: .make(yaml: yaml.botLogin),
        apiToken: .make(yaml: yaml.apiToken),
        pushToken: .make(yaml: yaml.pushToken),
        triggerJobId: yaml.triggerJobId,
        triggerJobName: yaml.triggerJobName,
        triggerProfile: yaml.triggerProfile,
        triggerPipeline: yaml.triggerPipeline
      )}
    }
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
  public struct Signal {
    public var method: String
    public var body: Template
    public static func make(yaml: Yaml.Signal) throws -> Self { try .init(
      method: yaml.method,
      body: .make(yaml: yaml.body)
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
  public struct ResolveApprovalStatuses: Query {
    public var cfg: Configuration
    public var approval: Fusion.Approval
    public init(cfg: Configuration, approval: Fusion.Approval) {
      self.cfg = cfg
      self.approval = approval
    }
    public typealias Reply = [UInt: Fusion.Status]
  }
  public struct PersistApprovalStatuses: Query {
    public var cfg: Configuration
    public var approval: Fusion.Approval
    public var review: Json.GitlabReviewState
    public var statuses: [UInt : Fusion.Status]
    public init(
      cfg: Configuration,
      approval: Fusion.Approval,
      review: Json.GitlabReviewState,
      statuses: [UInt : Fusion.Status]
    ) {
      self.cfg = cfg
      self.approval = approval
      self.review = review
      self.statuses = statuses
    }
    public typealias Reply = Void
  }
  public struct ResolveUserActivity: Query {
    public var cfg: Configuration
    public var approval: Fusion.Approval
    public init(cfg: Configuration, approval: Fusion.Approval) {
      self.cfg = cfg
      self.approval = approval
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
    public var approval: Fusion.Approval
    public var userActivity: [String: Bool]
    public var user: String
    public var active: Bool
    public init(
      cfg: Configuration,
      pushUrl: String,
      approval: Fusion.Approval,
      userActivity: [String: Bool],
      user: String,
      active: Bool
    ) {
      self.cfg = cfg
      self.pushUrl = pushUrl
      self.approval = approval
      self.userActivity = userActivity
      self.user = user
      self.active = active
    }
    public typealias Reply = Void
  }
}
