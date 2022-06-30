import Foundation
import Facility
public struct Fusion {
  public var resolution: Lossy<Resolution>
  public var replication: Lossy<Replication>
  public var integration: Lossy<Integration>
  public static func make(
    mainatiners: Set<String>,
    yaml: Yaml.Controls.Fusion
  ) throws -> Self { try .init(
    resolution: yaml.resolution
      .map(Resolution.make(yaml:))
      .map(Lossy.value(_:))
      .get(Lossy.error(Thrown("resolution not configured"))),
    replication: yaml.replication
      .map(Replication.make(yaml:))
      .map(Lossy.value(_:))
      .get(Lossy.error(Thrown("replication not configured"))),
    integration: yaml.integration
      .reduce(mainatiners, Integration.make(mainatiners:yaml:))
      .map(Lossy.value(_:))
      .get(Lossy.error(Thrown("integration not configured")))
  )}
  public struct Resolution {
    public var createCommitMessage: Configuration.Template
    public var rules: [Rule]
    public static func make(
      yaml: Yaml.Controls.Fusion.Resolution
    ) throws -> Self { try .init(
      createCommitMessage: .make(yaml: yaml.createCommitMessage),
      rules: yaml.rules
        .map { yaml in try .init(
          title: yaml.title
            .map(Criteria.init(yaml:))
            .get(.init()),
          source: .init(yaml: yaml.source)
        )}
    )}
    public struct Rule {
      public var title: Criteria
      public var source: Criteria
    }
  }
  public struct Replication {
    public var target: String
    public var prefix: String
    public var source: Criteria
    public var createCommitMessage: Configuration.Template
    public static func make(
      yaml: Yaml.Controls.Fusion.Replication
    ) throws -> Self { try .init(
      target: yaml.target,
      prefix: yaml.prefix,
      source: .init(yaml: yaml.source),
      createCommitMessage: .make(yaml: yaml.createCommitMessage)
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
        commitMessage: createCommitMessage
      )
    }
    public func makeMerge(source: String, sha: String) throws -> Merge { try .init(
      fork: .init(value: sha),
      prefix: prefix,
      source: .init(name: source),
      target: .init(name: target),
      supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(sha)"),
      commitMessage: createCommitMessage
    )}
  }
  public struct Integration {
    public var rules: [Rule]
    public var prefix: String
    public var createCommitMessage: Configuration.Template
    public var exportTargets: Configuration.Template
    public static func make(
      mainatiners: Set<String>,
      yaml: Yaml.Controls.Fusion.Integration
    ) throws -> Self { try .init(
      rules: yaml.rules
        .map { yaml in try .init(
          mainatiners: mainatiners
            .union(Set(yaml.mainatiners.get([]))),
          source: .init(yaml: yaml.source),
          target: .init(yaml: yaml.target)
        )},
      prefix: yaml.prefix,
      createCommitMessage: .make(yaml: yaml.createCommitMessage),
      exportTargets: .make(yaml: yaml.exportTargets)
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
        commitMessage: createCommitMessage
      )
    }
    public func makeMerge(target: String, source: String, fork: String) throws -> Merge { try .init(
      fork: .init(value: fork),
      prefix: prefix,
      source: .init(name: source),
      target: .init(name: target),
      supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(fork)"),
      commitMessage: createCommitMessage
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
    public var commitMessage: Configuration.Template
  }
}
