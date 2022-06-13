import Foundation
import Facility
public struct Configuration {
  public var git: Git
  public var env: [String: String]
  public var profile: Profile
  public var controls: Controls
  public init(
    git: Git,
    env: [String : String],
    profile: Profile,
    controls: Controls
  ) {
    self.git = git
    self.env = env
    self.profile = profile
    self.controls = controls
  }
  public func get(env key: String) throws -> String {
    try env[key].or { throw Thrown("No \(key) in environment") }
  }
  public struct Profile {
    public var profile: Git.File
    public var controls: Git.File
    public var codeOwnage: Git.File?
    public var fileTaboos: Git.File?
    public var obsolescence: Criteria?
    public var stencilTemplates: [String: String] = [:]
    public static func make(
      profile: Git.File,
      yaml: Yaml.Profile
    ) throws -> Self { try .init(
      profile: profile,
      controls: .init(
        ref: .make(remote: .init(name: yaml.controls.branch)),
        path: .init(value: yaml.controls.file)
      ),
      codeOwnage: yaml.codeOwnage
        .map(Path.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:)),
      fileTaboos: yaml.fileTaboos
        .map(Path.Relative.init(value:))
        .reduce(profile.ref, Git.File.init(ref:path:)),
      obsolescence: yaml.obsolescence
        .map(Criteria.init(yaml:))
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
    public var flow: Git.File?
    public var forbiddenCommits: [Git.Sha]
    public var stencilTemplates: [String: String] = [:]
    public var stencilCustom: AnyCodable?
    public var communication: [String: [Communication]] = [:]
    public var gitlabCi: Lossy<GitlabCi> = .error(Thrown("gitlabCi not configured"))
    public static func make(
      ref: Git.Ref,
      env: [String: String],
      yaml: Yaml.Controls
    ) throws -> Self { try .init(
      mainatiners: .init(yaml.mainatiners.or([])),
      awardApproval: yaml.awardApproval
        .map(Path.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      production: yaml.production
        .map(Path.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      requisition: yaml.requisition
        .map(Path.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      flow: yaml.flow
        .map(Path.Relative.init(value:))
        .reduce(ref, Git.File.init(ref:path:)),
      forbiddenCommits: yaml.forbiddenCommits
        .or([])
        .map(Git.Sha.init(value:))
    )}
  }
}
public extension String {
  func get(env: [String: String]) throws -> String {
    try env[self].or { throw Thrown("No env \(self)") }
  }
}
//  public struct Assets {
//    public var branch: Git.Branch
//    public var products: Products?
//    public var activeUsers: Git.File?
//    public static func make(yaml: Yaml.Assets) throws -> Self {
//      let branch = try Git.Branch(name: yaml.branch)
//      let ref = Git.Ref.make(remote: branch)
//      return try .init(
//        branch: branch,
//        products: yaml.products
//          .reduce(ref, Products.make(ref:yaml:)),
//        activeUsers: yaml.activeUsers
//          .map(Path.Relative.init(value:))
//          .reduce(ref, Git.File.init(ref:path:))
//      )
//    }
//    public struct Products {
//      public var builds: Git.File
//      public var maxBuildsCount: Int?
//      public var buildMessageTemplate: String
//      public var versions: Git.File
//      public var versionMessageTemplate: String
//      public static func make(
//        ref: Git.Ref,
//        yaml: Yaml.Assets.Products
//      ) throws -> Self { try .init(
//        builds: .init(ref: ref, path: .init(value: yaml.builds)),
//        maxBuildsCount: yaml.maxBuildsCount
//          .map { ($0 < 10).then(10).or($0) },
//        buildMessageTemplate: yaml.buildMessageTemplate,
//        versions: .init(ref: ref, path: .init(value: yaml.versions)),
//        versionMessageTemplate: yaml.versionMessageTemplate
//      )}
//    }
//  }
//  public struct Stencil {
//    public var templates: [String: String] = [:]
//    public var custom: AnyCodable?
//    public init() {}
//  }
//  public struct Requisite {
//    public var provisions: Git.Dir?
//    public var keychain: Keychain?
//    public struct Keychain {
//      public var crypto: Git.File
//      public var password: Token
//      public static func make(ref: Git.Ref, yaml: Yaml.Keychain) throws -> Self { try .init(
//        crypto: .init(ref: ref, path: .init(value: yaml.crypto)),
//        password: .init(yaml: yaml.password)
//      )}
//    }
//    public static func make(ref: Git.Ref, yaml: Yaml.Requisite) throws -> Self { try .init(
//      provisions: yaml.provisions
//        .map(Path.Relative.init(value:))
//        .reduce(ref, Git.Dir.init(ref:path:)),
//      keychain: yaml.keychain.reduce(ref, Keychain.make(ref:yaml:))
//    )}
//  }
//  public struct Product {
//    public var name: String
//    public var deployTag: DeployTag
//    public var releaseBranch: ReleaseBranch
//    public static func make(yaml: Yaml.Controls) throws -> [Self] {
//      let maintainers = yaml.mainatiners
//        .map(Set.init(_:))
//        .or([])
//      guard let yaml = yaml.products else { return [] }
//      return try yaml.map { key, value in try .init(
//        name: key,
//        deployTag: .init(
//          mainatiners: value.deployTag.mainatiners
//            .map(Set.init(_:))
//            .or([])
//            .union(maintainers),
//          nameRule: .init(yaml: value.deployTag.nameRule),
//          createTemplate: value.deployTag.createTemplate,
//          parseBuildTemplate: value.deployTag.parseBuildTemplate,
//          parseVersionTemplate: value.deployTag.parseVersionTemplate
//        ),
//        releaseBranch: .init(
//          mainatiners: value.releaseBranch.mainatiners
//            .map(Set.init(_:))
//            .or([])
//            .union(maintainers),
//          nameRule: .init(yaml: value.releaseBranch.nameRule),
//          createTemplate: value.releaseBranch.createTemplate,
//          parseVersionTemplate: value.releaseBranch.parseVersionTemplate,
//          createNextVersionTemplate: value.releaseBranch.createNextVersionTemplate,
//          createHotfixVersionTemplate: value.releaseBranch.createHotfixVersionTemplate
//        )
//      )}
//    }
//    public struct DeployTag {
//      public var mainatiners: Set<String>
//      public var nameRule: Criteria
//      public var createTemplate: String
//      public var parseBuildTemplate: String
//      public var parseVersionTemplate: String
//    }
//    public struct ReleaseBranch {
//      public var mainatiners: Set<String>
//      public var nameRule: Criteria
//      public var createTemplate: String
//      public var parseVersionTemplate: String
//      public var createNextVersionTemplate: String
//      public var createHotfixVersionTemplate: String
//    }
//    public struct VersionBumpMessage: Codable {
//      public var product: String
//      public var versions: [String: String]
//      public var custom: AnyCodable?
//      public init(
//        product: String,
//        versions: [String : String],
//        custom: AnyCodable?
//      ) {
//        self.product = product
//        self.versions = versions
//        self.custom = custom
//      }
//    }
//    public struct NextVersion: Codable {
//      public var version: String
//      public var product: String
//      public var custom: AnyCodable?
//      public init(
//        version: String,
//        product: String,
//        custom: AnyCodable?
//      ) {
//        self.version = version
//        self.product = product
//        self.custom = custom
//      }
//    }
//  }

//  public struct Context: Encodable {
//    public var git: Git
//    public var env: [String: String]
//    public var custom: AnyCodable?
//    public struct Git: Encodable {
//      public var author: String? = nil
//      public var head: String? = nil
//    }
//  }
//  public struct Review {
//    public var titleRule: Criteria?
//    public var messageTemplate: String?
//    public static func make(yaml: Yaml.Review) throws -> Self { try .init(
//      titleRule: yaml.titleRule
//        .map(Criteria.init(yaml:)),
//      messageTemplate: yaml.messageTemplate
//    )}
//  }
//  public struct Replication {
//    public var messageTemplate: String
//    public var prefix: String
//    public var source: Criteria
//    public var target: String
//    public static func make(yaml: Yaml.Replication) throws -> Self { try .init(
//      messageTemplate: yaml.messageTemplate,
//      prefix: yaml.prefix,
//      source: .init(yaml: yaml.source),
//      target: yaml.target
//    )}
//    public func makeMerge(branch: String) throws -> Merge {
//      let components = branch.components(separatedBy: "/-/")
//      guard
//        components.count == 4,
//        components[0] == prefix,
//        components[1] == target
//      else { throw Thrown("Wrong replication branch format: \(branch)") }
//      return try .init(
//        fork: .init(value: components[2]),
//        prefix: prefix,
//        source: .init(name: components[1]),
//        target: .init(name: target),
//        supply: .init(name: branch),
//        template: messageTemplate
//      )
//    }
//    public func makeMerge(source: String, sha: String) throws -> Merge { try .init(
//      fork: .init(value: sha),
//      prefix: prefix,
//      source: .init(name: source),
//      target: .init(name: target),
//      supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(sha)"),
//      template: messageTemplate
//    )}
//  }
//  public struct Integration {
//    public var messageTemplate: String
//    public var prefix: String
//    public var rules: [Rule]
//    public static func make(yaml: Yaml.Controls) throws -> Self? {
//      var mainatiners = yaml.mainatiners.map(Set.init(_:)).or([])
//      guard let yaml = yaml.integration else { return nil }
//      mainatiners = yaml.mainatiners
//        .map(Set.init(_:))
//        .or([])
//        .union(mainatiners)
//      return try .init(
//        messageTemplate: yaml.messageTemplate,
//        prefix: yaml.prefix,
//        rules: yaml.rules.map { rule in try .init(
//          mainatiners: rule.mainatiners
//            .map(Set.init(_:))
//            .or([])
//            .union(mainatiners),
//          source: .init(yaml: rule.source),
//          target: .init(yaml: rule.target)
//        )}
//      )
//    }
//    public func makeMerge(target: String, source: String, sha: String) throws -> Merge { try .init(
//      fork: .init(value: sha),
//      prefix: prefix,
//      source: .init(name: source),
//      target: .init(name: target),
//      supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(sha)"),
//      template: messageTemplate
//    )}
//    public func makeMerge(branch: String) throws -> Merge {
//      let components = branch.components(separatedBy: "/-/")
//      guard components.count == 4, components[0] == prefix else {
//        throw Thrown("Wrong integration branch format: \(branch)")
//      }
//      return try .init(
//        fork: .init(value: components[3]),
//        prefix: prefix,
//        source: .init(name: components[2]),
//        target: .init(name: components[1]),
//        supply: .init(name: branch),
//        template: messageTemplate
//      )
//    }
//    public struct Rule {
//      public var mainatiners: Set<String>
//      public var source: Criteria
//      public var target: Criteria
//    }
//  }
//  public struct Merge {
//    public var fork: Git.Sha
//    public var prefix: String
//    public var source: Git.Branch
//    public var target: Git.Branch
//    public var supply: Git.Branch
//    public var template: String
//    public struct Context: Encodable {
//      public var env: [String: String]
//      public var custom: AnyCodable?
//      public var fork: String
//      public var source: String
//      public var target: String
//      public var supply: String
//      public static func make(cfg: Configuration, merge: Merge) -> Self { .init(
//        env: cfg.env,
//        custom: cfg.custom,
//        fork: merge.fork.value,
//        source: merge.source.name,
//        target: merge.target.name,
//        supply: merge.supply.name
//      )}
//    }
//  }
//}
