import Foundation
import Facility
public struct Flow {
  public var squash: Lossy<Squash>
  public var replication: Lossy<Replication>
  public var integration: Lossy<Integration>
  public static func make(
    mainatiners: Set<String>,
    yaml: Yaml.Controls.Flow
  ) throws -> Self { try .init(
    squash: yaml.squash
      .map(Squash.make(yaml:))
      .map(Lossy.value(_:))
      .or(Lossy.error(Thrown("review not configured"))),
    replication: yaml.replication
      .map(Replication.make(yaml:))
      .map(Lossy.value(_:))
      .or(Lossy.error(Thrown("replication not configured"))),
    integration: yaml.integration
      .reduce(mainatiners, Integration.make(mainatiners:yaml:))
      .map(Lossy.value(_:))
      .or(Lossy.error(Thrown("integration not configured")))
  )}
  public struct Squash {
    public var messageTemplate: String
    public var titleRule: Lossy<Criteria>
    public static func make(
      yaml: Yaml.Controls.Flow.Squash
    ) throws -> Self { try .init(
      messageTemplate: yaml.messageTemplate,
      titleRule: yaml.titleRule
        .map(Criteria.init(yaml:))
        .map(Lossy.value(_:))
        .or(.error(Thrown("titleRule not configured")))
    )}
  }
  public struct Replication {
    public var target: String
    public var prefix: String
    public var source: Criteria
    public var messageTemplate: String
    public static func make(
      yaml: Yaml.Controls.Flow.Replication
    ) throws -> Self { try .init(
      target: yaml.target,
      prefix: yaml.prefix,
      source: .init(yaml: yaml.source),
      messageTemplate: yaml.messageTemplate
    )}
    public func makeMerge(supply: String) throws -> Merge {
      let components = supply.components(separatedBy: "/-/")
      guard
        components.count == 4,
        components[0] == prefix,
        components[1] == target
      else { throw Thrown("Wrong replication branch format: \(supply)") }
      return try .init(
        fork: .init(value: components[2]),
        prefix: prefix,
        source: .init(name: components[1]),
        target: .init(name: target),
        supply: .init(name: supply),
        messageTemplate: messageTemplate
      )
    }
    public func makeMerge(source: String, sha: String) throws -> Merge { try .init(
      fork: .init(value: sha),
      prefix: prefix,
      source: .init(name: source),
      target: .init(name: target),
      supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(sha)"),
      messageTemplate: messageTemplate
    )}
  }
  public struct Integration {
    public var rules: [Rule]
    public var prefix: String
    public var messageTemplate: String
    public static func make(
      mainatiners: Set<String>,
      yaml: Yaml.Controls.Flow.Integration
    ) throws -> Self { try .init(
      rules: yaml.rules
        .map { yaml in try .init(
          mainatiners: mainatiners
            .union(Set(yaml.mainatiners.or([]))),
          source: .init(yaml: yaml.source),
          target: .init(yaml: yaml.target)
        )},
      prefix: yaml.prefix,
      messageTemplate: yaml.messageTemplate
    )}
    public func makeMerge(supply: String) throws -> Merge {
      let components = supply.components(separatedBy: "/-/")
      guard components.count == 4, components[0] == prefix else {
        throw Thrown("Wrong integration branch format: \(supply)")
      }
      return try .init(
        fork: .init(value: components[3]),
        prefix: prefix,
        source: .init(name: components[2]),
        target: .init(name: components[1]),
        supply: .init(name: supply),
        messageTemplate: messageTemplate
      )
    }
    public func makeMerge(target: String, source: String, sha: String) throws -> Merge { try .init(
      fork: .init(value: sha),
      prefix: prefix,
      source: .init(name: source),
      target: .init(name: target),
      supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(sha)"),
      messageTemplate: messageTemplate
    )}
    public struct Rule {
      public var mainatiners: Set<String>
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
    public var messageTemplate: String
  }
}