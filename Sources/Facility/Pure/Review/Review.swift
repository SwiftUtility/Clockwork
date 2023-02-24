import Foundation
import Facility
public struct Review {
  public var storage: Configuration.Asset
  public var rules: Configuration.Secret
  public var exportTargets: Configuration.Template
  public var createMergeTitle: Configuration.Template
  public var createMergeCommit: Configuration.Template
  public var createSquashCommit: Configuration.Template
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
    exportTargets: .make(yaml: yaml.exportFusion),
    createMergeTitle: .make(yaml: yaml.createMergeTitle),
    createMergeCommit: .make(yaml: yaml.createMergeCommit),
    createSquashCommit: .make(yaml: yaml.createSquashCommit),
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
    propositions: yaml.propositions.map(Proposition.make(name:yaml:)).indexed(\.name)
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
  public struct Approve: Equatable {
    public var login: String
    public var commit: Git.Sha
    public var resolution: Resolution
    public var diff: String? { resolution.approved.not.then(commit.value) }
    public mutating func shift(sha: Git.Sha, to other: Git.Sha) {
      if commit == sha { commit = other }
    }
    public static func make(
      login: String,
      yaml: [String: String]
    ) throws -> Self {
      guard
        yaml.count == 1,
        let resolution = yaml.keys.first.flatMap(Resolution.init(rawValue:)),
        let commit = yaml.values.first
      else { throw Thrown("Wrong approver format") }
      return try .init(
        login: login,
        commit: .make(value: commit),
        resolution: resolution
      )
    }
    public static func make(
      login: String,
      commit: Git.Sha
    ) -> Self { .init(
      login: login,
      commit: commit,
      resolution: .fragil
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
    public var fusion: Fusion
    public var addAward: Bool = false
    public static func make(
      merge: Json.GitlabMergeState,
      fusion: Review.Fusion
    ) throws -> Self { try .init(
      head: .make(merge: merge),
      merge: merge,
      fusion: fusion
    )}
  }
  public enum Problem {
    case badSource(String)
    case targetNotProtected
    case targetMismatch(Git.Branch)
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
    case forkNotProtected
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
      case .forkNotProtected: return true
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
  public struct Approver: Encodable {
    public var login: String
    public var miss: Bool
    public var fragil: Bool = false
    public var advance: Bool = false
    public var diff: String? = nil
    public var hold: Bool = false
    public var comments: Int? = nil
    static func present(reviewer: Review.Approve) -> Self { .init(
      login: reviewer.login,
      miss: false,
      fragil: reviewer.resolution.fragil,
      advance: reviewer.resolution.approved && reviewer.resolution.fragil.not,
      diff: reviewer.resolution.approved.not.then(reviewer.commit.value)
    )}
  }
  public struct Problems: Encodable {
    public var badSource: String? = nil
    public var targetNotProtected: Bool = false
    public var targetMismatch: String? = nil
    public var sourceIsProtected: Bool = false
    public var multipleKinds: [String]? = nil
    public var undefinedKind: Bool = false
    public var authorIsBot: Bool = false
    public var authorIsNotBot: String? = nil
    public var sanity: String? = nil
    public var extraCommits: [String]? = nil
    public var notCherry: Bool = false
    public var notForward: Bool = false
    public var forkInTarget: Bool = false
    public var forkNotProtected: Bool = false
    public var forkNotInSource: Bool = false
    public var forkParentNotInTarget: Bool = false
    public var sourceNotAtFrok: Bool = false
    public var conflicts: Bool = false
    public var squashCheck: Bool = false
    public var draft: Bool = false
    public var discussions: Bool = false
    public var badTitle: Bool = false
    public var taskMismatch: Bool = false
    public var holders: Bool = false
    public var unknownUsers: [String]? = nil
    public var unknownTeams: [String]? = nil
    public var confusedTeams: [String]? = nil
    public var orphaned: [String]? = nil
    public var unapprovableTeams: [String]? = nil
    mutating func register(problem: Review.Problem) {
      switch problem {
      case .badSource(let value): badSource = value
      case .targetNotProtected: targetNotProtected = true
      case .targetMismatch(let value): targetMismatch = value.name
      case .sourceIsProtected: sourceIsProtected = true
      case .multipleKinds(let value): multipleKinds = value.sortedNonEmpty
      case .undefinedKind: undefinedKind = true
      case .authorIsBot: authorIsBot = true
      case .authorIsNotBot(let value): authorIsNotBot = value
      case .sanity(let value): sanity = value
      case .extraCommits(let value): extraCommits = value.map(\.name).sortedNonEmpty
      case .notCherry: notCherry = true
      case .notForward: notForward = true
      case .forkInTarget: forkInTarget = true
      case .forkNotProtected: forkNotProtected = true
      case .forkNotInSource: forkNotInSource = true
      case .forkParentNotInTarget: forkParentNotInTarget = true
      case .sourceNotAtFrok: sourceNotAtFrok = true
      case .conflicts: conflicts = true
      case .squashCheck: squashCheck = true
      case .draft: draft = true
      case .discussions: discussions = true
      case .badTitle: badTitle = true
      case .taskMismatch: taskMismatch = true
      case .holders: holders = true
      case .unknownUsers(let value): unknownUsers = value.sortedNonEmpty
      case .unknownTeams(let value): unknownTeams = value.sortedNonEmpty
      case .confusedTeams(let value): confusedTeams = value.sortedNonEmpty
      case .orphaned(let value): orphaned = value.sortedNonEmpty
      case .unapprovableTeams(let value): unapprovableTeams = value.sortedNonEmpty
      }
    }
  }
}
