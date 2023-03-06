import Foundation
import Facility
public struct Configuration {
  public let bag = Report.Bag.shared
  public var git: Git
  public var env: [String: String]
  public var profile: Profile
  public var templates: [String: String] = [:]
  public var gitlab: Lossy<Gitlab> = .error(Thrown())
  public var jira: Lossy<Jira> = .error(Thrown())
  public var clean: Chat.Clean { .init(cfg: self) }
  public static func make(
    git: Git,
    env: [String: String],
    profile: Configuration.Profile
  ) -> Self { .init(
    git: git,
    env: env,
    profile: profile
  )}
  public struct Profile {
    public var location: Git.File
    public var version: String
    public var storageBranch: Git.Branch?
    public var storageTemplate: Template?
    public var gitlab: Git.File?
    public var slack: Git.File?
    public var rocket: Git.File?
    public var jira: Git.File?
    public var templates: Git.Dir?
    public var codeOwnage: Git.File?
    public var review: Lossy<Git.File>
    public var fileTaboos: Lossy<Git.File>
    public var cocoapods: Lossy<Git.File>
    public var production: Lossy<Git.File>
    public var requisition: Lossy<Git.File>
    public static func make(
      location: Git.File,
      yaml: Yaml.Profile
    ) throws -> Self { try .init(
      location: location,
      version: yaml.version,
      storageBranch: yaml.storage.map(\.branch).map(Git.Branch.make(name:)),
      storageTemplate: yaml.storage.map(\.createCommitMessage).map(Template.make(yaml:)),
      gitlab: yaml.gitlab
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:)),
      slack: yaml.slack
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:)),
      rocket: yaml.rocket
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:)),
      jira: yaml.jira
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:)),
      templates: yaml.templates
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.Dir.init(ref:path:)),
      codeOwnage: yaml.codeOwnage
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:)),
      review: yaml.review
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("fusion not configured"))),
      fileTaboos: yaml.fileTaboos
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("fileTaboos not configured"))),
      cocoapods: yaml.cocoapods
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("cocoapods not configured"))),
      production: yaml.flow
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("production not configured"))),
      requisition: yaml.requisites
        .map(Files.Relative.init(value:))
        .reduce(location.ref, Git.File.init(ref:path:))
        .map(Lossy.value(_:))
        .get(.error(Thrown("requisites not configured")))
    )}
    public func checkSanity(criteria: Criteria?) -> Bool {
      guard let criteria = criteria else { return false }
      guard let codeOwnage = codeOwnage else { return false }
      return criteria.isMet(location.path.value) && criteria.isMet(codeOwnage.path.value)
    }
  }
  public enum ParseStdin: Query {
    case ignore
    case lines
    case json
    case yaml
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
      branch: .make(name: yaml.branch),
      createCommitMessage: .make(yaml: yaml.createCommitMessage)
    )}
  }
  public enum Template {
    case name(String)
    case value(String)
    public var name: String {
      switch self {
      case .value(let value): return String(value.prefix(30))
      case .name(let name): return name
      }
    }
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
        ref: .make(remote: .make(name: gitFile.branch)),
        path: .init(value: gitFile.path)
      ))
      default: throw Thrown("Wrong secret format")
      }
    }
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
