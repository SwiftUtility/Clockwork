import Foundation
import Facility
public struct Review {
  public var storage: Configuration.Asset
  public var rules: Configuration.Secret
  public var exportTargets: Configuration.Template
  public var createMessage: Configuration.Template
  public var duplication: Duplication
  public var replication: Replication
  public var integration: Integration
  public var propogation: Propogation
  public var propositions: [String: Proposition]
  public static func make(
    yaml: Yaml.Review
  ) throws -> Self { try .init(
    storage: .make(yaml: yaml.storage),
    rules: .make(yaml: yaml.rules),
    exportTargets: .make(yaml: yaml.exportTargets),
    createMessage: .make(yaml: yaml.createMessage),
    duplication: .init(
      autoApproveFork: yaml.duplication.autoApproveFork.get(false),
      allowOrphaned: yaml.duplication.allowOrphaned.get(false)
    ),
    replication: .init(
      autoApproveFork: yaml.replication.autoApproveFork.get(false),
      allowOrphaned: yaml.replication.allowOrphaned.get(false)
    ),
    integration: .init(
      autoApproveFork: yaml.integration.autoApproveFork.get(false),
      allowOrphaned: yaml.integration.allowOrphaned.get(false)
    ),
    propogation: .init(
      autoApproveFork: yaml.propogation.autoApproveFork.get(false),
      allowOrphaned: yaml.propogation.allowOrphaned.get(false)
    ),
    propositions: yaml.propositions
      .map(Proposition.make(name:yaml:))
      .reduce(into: [:], { $0[$1.name] = $1 })
  )}
  public struct Duplication {
    public var autoApproveFork: Bool
    public var allowOrphaned: Bool
  }
  public struct Replication {
    public var autoApproveFork: Bool
    public var allowOrphaned: Bool
  }
  public struct Integration {
    public var autoApproveFork: Bool
    public var allowOrphaned: Bool
  }
  public struct Propogation {
    public var autoApproveFork: Bool
    public var allowOrphaned: Bool
  }
  public struct Proposition {
    public var name: String
    public var source: Criteria
    public var title: Criteria?
    public var task: NSRegularExpression?
    public static func make(name: String, yaml: Yaml.Review.Proposition) throws -> Self { try .init(
      name: name,
      source: .init(yaml: yaml.source),
      title: yaml.title.map(Criteria.init(yaml:)),
      task: yaml.task
        .map({ try NSRegularExpression(pattern: $0, options: [.anchorsMatchLines]) })
    )}
  }
}
