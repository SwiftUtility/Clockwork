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
    func makePropose(source branch: Git.Branch, target: Git.Branch) -> Fusion? {
      guard self.source.isMet(branch.name) else { return nil }
      return .propose(.init(source: branch, target: target, proposition: self))
    }
    public static func make(name: String, yaml: Yaml.Review.Proposition) throws -> Self { try .init(
      name: name,
      source: .init(yaml: yaml.source),
      title: yaml.title.map(Criteria.init(yaml:)),
      task: yaml.task
        .map({ try NSRegularExpression(pattern: $0, options: [.anchorsMatchLines]) })
    )}
  }
  public struct Reviewer {
    public var login: String
    public var commit: Git.Sha
    public var resolution: Resolution
    public static func make(
      login: String,
      yaml: Yaml.Review.Storage.Reviewer
    ) throws -> Self { try .init(
      login: login,
      commit: .make(value: yaml.commit),
      resolution: .make(yaml: yaml.resolution)
    )}
  }
  public enum Resolution: String, Encodable {
    case fragil
    case advance
    case obsolete
    public var approved: Bool {
      if case .obsolete = self { return false } else { return true }
    }
    public var fragil: Bool {
      if case .fragil = self { return true } else { return false }
    }
    public static func make(yaml: Yaml.Review.Storage.Resolution) -> Self {
      switch yaml {
      case .fragil: return .fragil
      case .advance: return .advance
      case .obsolete: return .obsolete
      }
    }
  }
  public enum Kind {
    case squash(Proposition)
    case merge(Merge)
    public struct Merge {
      public var fork: Git.Sha
      public var original: Git.Branch
      public var prefix: Fusion.Prefix
    }
  }
  public enum Phase: String, Encodable {
    case block
    case stuck
    case amend
    case ready
    public static func make(yaml: Yaml.Review.Storage.Phase) -> Self {
      switch yaml {
      case .block: return .block
      case .stuck: return .stuck
      case .amend: return .amend
      case .ready: return .ready
      }
    }
  }
  public struct Change {
    public var head: Git.Sha
    public var merge: Json.GitlabMergeState
    public var ownage: [String: Criteria]
    public var fusion: Fusion
    public var addAward: String? = nil
  }
  public enum Problem {
    case badSource(String)
    case targetNotProtected
    case targetMismatch
    case sourceIsProtected
    case multipleKinds([String])
    case undefinedKind
    case authorIsBot
    case authorIsNotBot(String)
    case sanity(String)
    case extraCommits(Set<Git.Branch>)
    case notCherry
    case notForward
    case forkInTarget
    case forkNotInOriginal
    case forkNotInSource
    case forkParentNotInTarget
    case sourceNotAtFrok
    case conflicts
    case squashCheck
    case draft
    case discussions([String: Int])
    case badTitle
    case taskMismatch
    case holders(Set<String>)
    case unknownUsers(Set<String>)
    case unknownTeams(Set<String>)
    case confusedTeams(Set<String>)
    case orphaned(Set<String>)
    case unapprovableTeams(Set<String>)
    var blocking: Bool {
      switch self {
      case .badSource: return true
      case .targetNotProtected: return true
      case .targetMismatch: return true
      case .sourceIsProtected: return true
      case .multipleKinds: return true
      case .undefinedKind: return true
      case .authorIsBot: return true
      case .authorIsNotBot: return true
      case .sanity: return true
      case .extraCommits: return true
      case .notCherry: return true
      case .notForward: return true
      case .forkInTarget: return true
      case .forkNotInOriginal: return true
      case .forkNotInSource: return true
      case .forkParentNotInTarget: return true
      case .sourceNotAtFrok: return true
      case .conflicts: return true
      default: return false
      }
    }
    var verifiable: Bool {
      switch self {
      case .squashCheck: return true
      case .draft: return true
      case .discussions: return true
      case .badTitle: return true
      case .taskMismatch: return true
      case .holders: return true
      default: return false
      }
    }
    var skippable: Bool {
      switch self {
      case .holders: return true
      case .unknownUsers: return true
      case .unknownTeams: return true
      case .confusedTeams: return true
      case .orphaned: return true
      case .unapprovableTeams: return true
      default: return false
      }
    }
  }
}
