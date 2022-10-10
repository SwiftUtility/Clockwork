import Foundation
import Facility
public struct Configuration {
  public var git: Git
  public var env: [String: String]
  public var profile: Profile
  public var templates: [String: String]
  public var context: AnyCodable?
  public var gitlabCi: Lossy<GitlabCi>
  public var slack: Lossy<Slack>
  public static func make(
    git: Git,
    env: [String: String],
    profile: Configuration.Profile,
    templates: [String: String],
    context: AnyCodable? = nil,
    gitlabCi: Lossy<GitlabCi>,
    slack: Lossy<Slack>
  ) -> Self { .init(
    git: git,
    env: env,
    profile: profile,
    templates: templates,
    context: context,
    gitlabCi: gitlabCi,
    slack: slack
  )}
  public struct Profile {
    public var profile: Git.File
    public var gitlabCi: GitlabCi?
    public var slack: Slack?
    public var context: Git.File?
    public var templates: Git.Dir?
    public var fusion: Lossy<Git.File>
    public var codeOwnage: Git.File?
    public var fileTaboos: Lossy<Git.File>
    public var cocoapods: Lossy<Git.File>
    public var production: Lossy<Git.File>
    public var requisition: Lossy<Git.File>
    public static func make(
      profile: Git.File,
      yaml: Yaml.Profile
    ) throws -> Self { try .init(
      profile: profile,
      gitlabCi: yaml.gitlabCi
        .map(GitlabCi.make(yaml:)),
      slack: yaml.slack
        .reduce(profile.ref, Slack.make(ref:yaml:)),
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
        .reduce(profile.ref, Git.File.init(ref:path:)),
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
    public func checkSanity(criteria: Criteria?) -> Bool {
      guard let criteria = criteria else { return false }
      guard let codeOwnage = codeOwnage else { return false }
      return criteria.isMet(profile.path.value) && criteria.isMet(codeOwnage.path.value)
    }
    public struct GitlabCi {
      public var token: Secret
      public var trigger: Yaml.GitlabCi.Trigger
      public static func make(
        yaml: Yaml.GitlabCi
      ) throws -> Self { try .init(
        token: .make(yaml: yaml.token),
        trigger: yaml.trigger
      )}
    }
    public struct Slack {
      public var token: Secret
      public var signals: Git.File
      public static func make(
        ref: Git.Ref,
        yaml: Yaml.Slack
      ) throws -> Self { try .init(
        token: .make(yaml: yaml.token),
        signals: .init(ref: ref, path: .init(value: yaml.signals))
      )}
    }
  }
  public enum ReadStdin: Query {
    case ignore
    case lines
    case json
    public typealias Reply = AnyCodable?
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
    case sysFile(String)
    case gitFile(Git.File)
    public static func make(yaml: Yaml.Secret) throws -> Self {
      switch (yaml.value, yaml.envVar, yaml.envFile, yaml.sysFile, yaml.gitFile) {
      case (let value?, nil, nil, nil, nil): return .value(value)
      case (nil, let envVar?, nil, nil, nil): return .envVar(envVar)
      case (nil, nil, let envFile?, nil, nil): return .envFile(envFile)
      case (nil, nil, nil, let sysFile?, nil): return .sysFile(sysFile)
      case (nil, nil, nil, nil, let gitFile?): return try .gitFile(.init(
        ref: .make(remote: .init(name: gitFile.branch)),
        path: .init(value: gitFile.path)
      ))
      default: throw Thrown("Wrong secret format")
      }
    }
  }
  public struct Thread: Encodable {
    public var channel: String
    public var ts: String
    public static func make(yaml: Yaml.Thread) -> Self { .init(
      channel: yaml.channel,
      ts: yaml.ts
    )}
    func serialize() -> String { "{channel: '\(channel)', ts: '\(ts)'}" }
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
  public struct ResolveFusionStatuses: Query {
    public var cfg: Configuration
    public var approval: Fusion.Approval
    public init(cfg: Configuration, approval: Fusion.Approval) {
      self.cfg = cfg
      self.approval = approval
    }
    public typealias Reply = [UInt: Fusion.Approval.Status]
  }
  public struct ResolveApprovers: Query {
    public var cfg: Configuration
    public var approval: Fusion.Approval
    public init(cfg: Configuration, approval: Fusion.Approval) {
      self.cfg = cfg
      self.approval = approval
    }
    public typealias Reply = [String: Fusion.Approval.Approver]
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
  public struct ParseYamlFile<T: Decodable>: Query {
    public var git: Git
    public var file: Git.File
    public init(
      git: Git,
      file: Git.File
    ) {
      self.git = git
      self.file = file
    }
    public typealias Reply = T
  }
  public struct ParseYamlSecret<T: Decodable>: Query {
    public var cfg: Configuration
    public var secret: Configuration.Secret
    public init(
      cfg: Configuration,
      secret: Configuration.Secret
    ) {
      self.cfg = cfg
      self.secret = secret
    }
    public typealias Reply = T
  }
  public struct PersistAsset: Query {
    public var cfg: Configuration
    public var asset: Configuration.Asset
    public var content: String
    public var message: String
    public init(
      cfg: Configuration,
      asset: Configuration.Asset,
      content: String,
      message: String
    ) {
      self.cfg = cfg
      self.asset = asset
      self.content = content
      self.message = message
    }
    public typealias Reply = Bool
  }
}
