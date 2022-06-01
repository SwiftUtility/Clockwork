import Foundation
import Facility
public struct Configuration {
  public var git: Git
  public var env: [String: String]
  public var profile: Profile
  public var stencil: Stencil = .init()
  public var gitlab: Yaml.Gitlab?
  public var notifications: [String: [Notification]] = [:]
  public var requisites: [String: Requisite] = [:]
  public var awardApproval: Git.File?
  public var builds: Git.File?
  public var versions: Git.File?
  public var vacationers: Git.File?
  public var review: Review?
  public var replication: Replication?
  public var integration: Integration?
  public init(
    git: Git,
    env: [String : String],
    profile: Profile
  ) {
    self.git = git
    self.env = env
    self.profile = profile
  }
  public var context: Context { .init(
    git: .init(author: git.author, head: git.head),
    env: env,
    custom: stencil.custom
  )}
  public func get(env key: String) throws -> String {
    try env[key].or { throw Thrown("No \(key) in environment") }
  }
  public func getReview() throws -> Review {
    try review.or { throw Thrown("Review not configured") }
  }
  public func getReplication() throws -> Replication {
    try replication.or { throw Thrown("Replication not configured") }
  }
  public func getIntegration() throws -> Integration {
    try integration.or { throw Thrown("Integration not configured") }
  }
  public struct Profile {
    public var profile: Git.File
    public var controls: Git.File
    public var fileApproval: Git.File?
    public var fileRules: Git.File?
    public var obsolete: Criteria?
    public var integrationJobTemplate: String?
    public var stencil: Stencil = .init()
    public static func make(
      file: Git.File,
      yaml: Yaml.Profile
    ) throws -> Self { try .init(
      profile: file,
      controls: .init(
        ref: .make(remote: .init(name: yaml.controls.branch)),
        path: .init(path: yaml.controls.file)
      ),
      fileApproval: yaml.fileApproval
        .map(Path.Relative.init(path:))
        .reduce(file.ref, Git.File.init(ref:path:)),
      fileRules: yaml.fileRules
        .map(Path.Relative.init(path:))
        .reduce(file.ref, Git.File.init(ref:path:)),
      obsolete: yaml.obsolete
        .map(Criteria.init(yaml:)),
      integrationJobTemplate: yaml.integrationJobTemplate
    )}
    public var sanityFiles: [String] {
      [profile.path.path]
      + [fileApproval, fileRules]
        .compactMap(\.?.path.path)
    }
  }
  public struct Assets {
    public var builds: Git.File?
    public var versions: Git.File?
    public var vacationers: Git.File?
    public static func make(yaml: Yaml.Assets) throws -> Self {
      let ref = try Git.Ref.make(remote: .init(name: yaml.branch))
      return try .init(
        builds: yaml.builds
          .map(Path.Relative.init(path:))
          .reduce(ref, Git.File.init(ref:path:)),
        versions: yaml.builds
          .map(Path.Relative.init(path:))
          .reduce(ref, Git.File.init(ref:path:)),
        vacationers: yaml.builds
          .map(Path.Relative.init(path:))
          .reduce(ref, Git.File.init(ref:path:))
      )
    }
  }
  public struct Stencil {
    public var templates: [String: String] = [:]
    public var custom: AnyCodable?
    public init() {}
  }
  public struct Requisite {
    public var provisions: Git.Dir?
    public var keychain: Keychain?
    public struct Keychain {
      public var crypto: Git.File
      public var password: Token
      public static func make(ref: Git.Ref, yaml: Yaml.Keychain) throws -> Self { try .init(
        crypto: .init(ref: ref, path: .init(path: yaml.crypto)),
        password: .init(yaml: yaml.password)
      )}
    }
    public static func make(ref: Git.Ref, yaml: Yaml.Requisite) throws -> Self { try .init(
      provisions: yaml.provisions
        .map(Path.Relative.init(path:))
        .reduce(ref, Git.Dir.init(ref:path:)),
      keychain: yaml.keychain.reduce(ref, Keychain.make(ref:yaml:))
    )}
  }
  public enum Notification {
    case slackHook(SlackHook)
    case jsonStdOut(JsonStdOut)
    public struct SlackHook {
      public var url: String
      public var template: String
      public var userName: String?
      public var channel: String?
      public var emojiIcon: String?
      public init(
        url: String,
        template: String,
        userName: String?,
        channel: String?,
        emojiIcon: String?
      ) {
        self.url = url
        self.template = template
        self.userName = userName
        self.channel = channel
        self.emojiIcon = emojiIcon
      }
      public func makePayload(text: String) -> Payload { .init(
        text: text,
        username: userName,
        channel: channel.map { "#\($0)" },
        iconEmoji: emojiIcon.map { ":\($0):" }
      )}
      public struct Payload: Encodable {
        var text: String
        var username: String?
        var channel: String?
        var iconEmoji: String?
      }
    }
    public struct JsonStdOut {
      public var template: String
      public init(template: String) { self.template = template }
    }
  }
  public enum Token {
    case value(String)
    case envVar(String)
    case envFile(String)
    public init(yaml: Yaml.Token) throws {
      if let value = yaml.value { self = .value(value) }
      else if let envVar = yaml.envVar { self = .envVar(envVar) }
      else if let envFile = yaml.envFile { self = .envFile(envFile) }
      else { throw Thrown("token not neither value, envVar nor envFile") }
    }
  }
  public struct Context: Encodable {
    public var git: Git
    public var env: [String: String]
    public var custom: AnyCodable?
    public struct Git: Encodable {
      public var author: String? = nil
      public var head: String? = nil
    }
  }
  public struct Review {
    public var titleRule: Criteria?
    public var messageTemplate: String?
    public static func make(yaml: Yaml.Review) throws -> Self { try .init(
      titleRule: yaml.titleRule
        .map(Criteria.init(yaml:)),
      messageTemplate: yaml.messageTemplate
    )}
  }
  public struct Replication {
    public var messageTemplate: String
    public var prefix: String
    public var source: Criteria
    public var target: String
    public static func make(yaml: Yaml.Replication) throws -> Self { try .init(
      messageTemplate: yaml.messageTemplate,
      prefix: yaml.prefix.or("replicate"),
      source: .init(yaml: yaml.source),
      target: yaml.target
    )}
    public func makeMerge(branch: String) throws -> Merge {
      let components = branch.components(separatedBy: "/-/")
      guard
        components.count == 4,
        components[0] == prefix,
        components[1] == target
      else { throw Thrown("Wrong replication branch format: \(branch)") }
      return try .init(
        fork: .init(ref: components[2]),
        prefix: prefix,
        source: .init(name: components[1]),
        target: .init(name: target),
        supply: .init(name: branch),
        template: messageTemplate
      )
    }
    public func makeMerge(source: String, sha: String) throws -> Merge { try .init(
      fork: .init(ref: sha),
      prefix: prefix,
      source: .init(name: source),
      target: .init(name: target),
      supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(sha)"),
      template: messageTemplate
    )}
  }
  public struct Integration {
    public var messageTemplate: String
    public var prefix: String
    public var rules: [Rule]
    public static func make(yaml: Yaml.Integration) throws -> Self {
      let users = yaml.users.map(Set.init(_:)).or([])
      return try .init(
        messageTemplate: yaml.messageTemplate,
        prefix: yaml.prefix.or("integrate"),
        rules: yaml.rules.map { rule in try .init(
          users: rule.users
            .map(Set.init(_:))
            .or([])
            .union(users),
          source: .init(yaml: rule.source),
          target: .init(yaml: rule.target)
        )}
      )
    }
    public func makeMerge(target: String, source: String, sha: String) throws -> Merge { try .init(
      fork: .init(ref: sha),
      prefix: prefix,
      source: .init(name: source),
      target: .init(name: target),
      supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(sha)"),
      template: messageTemplate
    )}
    public func makeMerge(branch: String) throws -> Merge {
      let components = branch.components(separatedBy: "/-/")
      guard components.count == 4, components[0] == prefix else {
        throw Thrown("Wrong integration branch format: \(branch)")
      }
      return try .init(
        fork: .init(ref: components[3]),
        prefix: prefix,
        source: .init(name: components[2]),
        target: .init(name: components[1]),
        supply: .init(name: branch),
        template: messageTemplate
      )
    }
    public struct Rule {
      public var users: Set<String>
      public var source: Criteria
      public var target: Criteria
    }
  }
  public struct Merge {
    public var fork: Git.Sha
    public var prefix: String
    public var source: Git.Branch
    public var target: Git.Branch
    public var supply: Git.Branch
    public var template: String
    public struct Context: Encodable {
      public var env: [String: String]
      public var custom: AnyCodable?
      public var fork: String
      public var source: String
      public var target: String
      public var supply: String
      public static func make(cfg: Configuration, merge: Merge) -> Self { .init(
        env: cfg.env,
        custom: cfg.stencil.custom,
        fork: merge.fork.ref,
        source: merge.source.name,
        target: merge.target.name,
        supply: merge.supply.name
      )}
    }
  }
}
