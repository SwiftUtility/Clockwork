import Foundation
import Facility
public struct Fusion {
  public var approval: Approval
  public var proposition: Proposition
  public var replication: Replication
  public var integration: Integration
  public var queue: Configuration.Asset
  public var createThread: Configuration.Template
  public var createMergeCommitMessage: Configuration.Template
  func createCommitMessage(kind: Kind) -> Configuration.Template {
    switch kind {
    case .proposition: return proposition.createCommitMessage
    case .replication: return replication.createCommitMessage
    case .integration: return integration.createCommitMessage
    }
  }
  public func makeKind(supply: String) throws -> Kind {
    guard let merge = try Merge.make(supply: supply) else {
      let rules = proposition.rules.filter { $0.source.isMet(supply) }
      guard rules.count < 2 else { throw Thrown("\(supply) matches multiple proposition rules") }
      return .proposition(rules.first)
    }
    if merge.prefix == "replicate" { return .replication(merge) }
    if merge.prefix == "integrate" { return .integration(merge) }
    throw Thrown("\(supply) prefix not configured")
  }
  public static func make(
    yaml: Yaml.Fusion
  ) throws -> Self { try .init(
    approval: .make(yaml: yaml.approval),
    proposition: .init(
      createCommitMessage: .make(yaml: yaml.proposition.createCommitMessage),
      rules: yaml.proposition.rules
        .map { yaml in try .init(
          title: .init(yaml: yaml.title),
          source: .init(yaml: yaml.source),
          task: yaml.task
            .map { try NSRegularExpression(pattern: $0, options: [.anchorsMatchLines]) }
        )}
    ),
    replication: .init(
      createCommitMessage: .make(yaml: yaml.replication.createCommitMessage)
    ),
    integration: .init(
      createCommitMessage: .make(yaml: yaml.integration.createCommitMessage),
      exportAvailableTargets: .make(yaml: yaml.integration.exportAvailableTargets)
    ),
    queue: .make(yaml: yaml.queue),
    createThread: .make(yaml: yaml.createThread),
    createMergeCommitMessage: .make(yaml: yaml.createMergeCommitMessage)
  )}
  public enum Kind {
    case proposition(Proposition.Rule?)
    case replication(Merge)
    case integration(Merge)
    public var merge: Merge? {
      switch self {
      case .proposition: return nil
      case .replication(let merge), .integration(let merge): return merge
      }
    }
    public var proposition: Bool {
      switch self {
      case .proposition: return true
      case .replication, .integration: return false
      }
    }
  }
  public struct Proposition {
    public var createCommitMessage: Configuration.Template
    public var rules: [Rule]
    public struct Rule {
      public var title: Criteria
      public var source: Criteria
      public var task: NSRegularExpression?
    }
  }
  public struct Replication {
    public var createCommitMessage: Configuration.Template
  }
  public struct Integration {
    public var createCommitMessage: Configuration.Template
    public var exportAvailableTargets: Configuration.Template
  }
  public struct Merge {
    public let fork: Git.Sha
    public let prefix: String
    public let source: Git.Branch
    public let target: Git.Branch
    public let supply: Git.Branch
    public static func make(
      fork: Git.Sha,
      source: Git.Branch,
      target: Git.Branch,
      isReplication: Bool
    ) throws -> Self {
      let prefix = isReplication.then("replicate").get("integrate")
      return try .init(
        fork: fork,
        prefix: prefix,
        source: source,
        target: target,
        supply: .init(name: "\(prefix)/-/\(target)/-/\(source)/-/\(fork)")
      )
    }
    public static func make(supply: String) throws -> Self? {
      let components = supply.components(separatedBy: "/-/")
      guard components.count == 4 else { return nil }
      return try .init(
        fork: .make(value: components[3]),
        prefix: components[0],
        source: .init(name: components[2]),
        target: .init(name: components[1]),
        supply: .init(name: supply)
      )
    }
  }
  public struct Queue {
    public internal(set) var queue: [String: [UInt]]
    public var yaml: String {
      guard queue.isEmpty.not else { return "{}\n" }
      return queue
        .map({ "'\($0.key)': [\($0.value.map(String.init(_:)).joined(separator: ", "))]\n" })
        .sorted()
        .joined()
    }
    public mutating func enqueue(review: UInt, target: String?) -> Set<UInt> {
      var result: Set<UInt> = []
      for (key, value) in queue {
        if key == target {
          guard !value.contains(where: { $0 == review }) else { continue }
          queue[key] = value + [review]
        } else {
          let targets = value.filter { $0 != review }
          guard value.count != targets.count else { continue }
          queue[key] = targets.isEmpty.else(targets)
          if let first = targets.first, first != value.first { result.insert(first) }
        }
      }
      if let target = target, queue[target] == nil { queue[target] = [review] }
      return result
    }
    public func isFirst(review: UInt, target: String) -> Bool { queue[target]?.first == review }
    public static func make(queue: [String: [UInt]]) -> Self { .init(queue: queue) }
    public struct Resolve: Query {
      public var cfg: Configuration
      public var fusion: Fusion
      public init(
        cfg: Configuration,
        fusion: Fusion
      ) {
        self.cfg = cfg
        self.fusion = fusion
      }
      public typealias Reply = Fusion.Queue
    }
    public struct Persist: Query {
      public var cfg: Configuration
      public var pushUrl: String
      public var fusion: Fusion
      public var reviewQueue: Fusion.Queue
      public var review: Json.GitlabReviewState
      public var queued: Bool
      public init(
        cfg: Configuration,
        pushUrl: String,
        fusion: Fusion,
        reviewQueue: Fusion.Queue,
        review: Json.GitlabReviewState,
        queued: Bool
      ) {
        self.cfg = cfg
        self.pushUrl = pushUrl
        self.fusion = fusion
        self.reviewQueue = reviewQueue
        self.review = review
        self.queued = queued
      }
      public typealias Reply = Void
    }
  }
  public struct Approval {
    public var rules: Git.File
    public var statuses: Configuration.Asset
    public var approvers: Configuration.Asset
    public var haters: Configuration.Secret?
    public static func make(yaml: Yaml.Fusion.Approval) throws -> Self { try .init(
      rules: .make(preset: yaml.rules),
      statuses: .make(yaml: yaml.statuses),
      approvers: .make(yaml: yaml.approvers),
      haters: yaml.haters
        .map(Configuration.Secret.make(yaml:))
    )}
    public struct Approver: Encodable {
      public var active: Bool
      public var slack: String
      var yaml: String { "{active: \(active), slack: '\(slack)}" }
      public static func make(yaml: Yaml.Fusion.Approval.Approver) -> Self { .init(
        active: yaml.active,
        slack: yaml.slack
      )}
      public static func make(active: Bool, slack: String) -> Self { .init(
        active: active,
        slack: slack
      )}
      public static func yaml(approvers: [String: Self]) -> String {
        guard approvers.isEmpty.not else { return "{}\n" }
        return approvers
          .sorted(by: { $0.key < $1.key })
          .map({ "'\($0.key)': \($0.value.yaml)\n" })
          .joined()
      }
    }
    public struct Rules {
      public var sanity: String?
      public var emergency: String?
      public var randoms: Randoms
      public var teams: [String: Team]
      public var authorship: [String: Set<String>]
      public var sourceBranch: [String: Criteria]
      public var targetBranch: [String: Criteria]
      public static func make(yaml: Yaml.Fusion.Approval.Rules) throws -> Self { try .init(
        sanity: yaml.sanity,
        emergency: yaml.emergency,
        randoms: .make(yaml: yaml.randoms),
        teams: yaml.teams
          .get([:])
          .mapValues(Team.make(yaml:)),
        authorship: yaml.authorship
          .get([:])
          .mapValues(Set.init(_:)),
        sourceBranch: yaml.sourceBranch
          .get([:])
          .mapValues(Criteria.init(yaml:)),
        targetBranch: yaml.targetBranch
          .get([:])
          .mapValues(Criteria.init(yaml:))
      )}
      public struct Team {
        public var quorum: Int
        public var labels: [String]
        public var mentions: [String]
        public var reserve: Set<String>
        public var optional: Set<String>
        public var required: Set<String>
        public var advanceApproval: Bool
        public var approvers: Set<String> { reserve.union(optional).union(required) }
        public static func make(yaml: Yaml.Fusion.Approval.Rules.Team) -> Self { .init(
          quorum: yaml.quorum,
          labels: yaml.labels.get([]),
          mentions: yaml.mentions.get([]),
          reserve: Set(yaml.reserve.get([])),
          optional: Set(yaml.optional.get([])),
          required: Set(yaml.required.get([])),
          advanceApproval: yaml.advanceApproval.get(false)
        )}
        public mutating func update(active: Set<String>) {
          required = required.intersection(active)
          optional = optional.intersection(active)
          reserve = reserve.intersection(active)
        }
        public mutating func update(involved: Set<String>) {
          quorum -= involved.intersection(approvers).count
          update(exclude: involved)
        }
        public mutating func update(exclude: Set<String>) {
          required = required.subtracting(exclude)
          optional = optional.subtracting(exclude)
          reserve = reserve.subtracting(exclude)
        }
        public mutating func update(optional involved: Set<String>) {
          let involved = reserve.intersection(involved)
          optional = optional.union(involved)
          reserve = reserve.subtracting(involved)
        }
        public var necessary: Set<String> {
          let optional = optional.union(required)
          let reserve = reserve.union(optional)
          guard reserve.count > quorum else { return reserve }
          guard optional.count > quorum else { return optional }
          return []
        }
      }
      public struct Randoms {
        public var quorum: Int
        public var baseWeight: Int
        public var weights: [String: Int]
        public var advanceApproval: Bool
        public static func make(yaml: Yaml.Fusion.Approval.Rules.Randoms) -> Self { .init(
          quorum: yaml.quorum,
          baseWeight: yaml.baseWeight,
          weights: yaml.weights
            .get([:]),
          advanceApproval: yaml.advanceApproval
        )}
      }
    }
    public struct Status {
      public var target: String
      public var authors: Set<String>
      public var randoms: Set<String>
      public var participants: Set<String>
      public var approves: [String: Approve]
      public var thread: Configuration.Thread
      mutating func invalidate(users: Set<String>) { approves
        .filter(\.value.resolution.approved)
        .keys
        .filter(users.contains(_:))
        .forEach { approves[$0]?.resolution = .outdated }
      }
      func makeAntagonitsts(kind: Kind, haters: [String: Set<String>]) -> Set<String> {
        guard kind.proposition else { return [] }
        return .init(haters.filter({ $0.value.intersection(authors).isEmpty.not }).keys)
      }
      public static func make(yaml: Yaml.Fusion.Approval.Status) throws -> Self { try .init(
        target: yaml.target,
        authors: .init(yaml.authors),
        randoms: yaml.randoms,
        participants: yaml.participants,
        approves: yaml.approves
          .mapValues(Approve.make(yaml:)),
        thread: .make(yaml: yaml.thread)
      )}
      public static func yaml(statuses: [UInt: Self]) -> String {
        var result = ""
        for (review, status) in statuses.sorted(by: { $0.key < $1.key }) {
          result += "'\(review)':\n"
          result += "  target: '\(status.target)'\n"
          let authors = status.authors
            .sorted()
            .map({ "'\($0)'" })
            .joined(separator: ",")
          result += "  authors: [\(authors)]\n"
          let randoms = status.randoms
            .sorted()
            .map { "'\($0)'" }
            .joined(separator: ",")
          result += "  randoms: [\(randoms)]\n"
          let participants = status.participants
            .sorted()
            .map { "'\($0)'" }
            .joined(separator: ",")
          result += "  participants: [\(participants)]\n"
          result += "  approves:\(status.approves.isEmpty.then(" {}").get(""))\n"
          for (user, approve) in status.approves.sorted(by: { $0.key < $1.key }) {
            result += "    '\(user)': {'\(approve.commit.value)': \(approve.resolution.rawValue)}\n"
          }
          result += "  thread: \(status.thread.serialize())\n"
        }
        return result.isEmpty.then("{}\n").get(result)
      }
      public static func make(
        target: String,
        authors: Set<String>,
        thread: Configuration.Thread,
        fork: Git.Sha?
      ) -> Self {
        let approve = try? Approve(commit: ?!fork, resolution: .fragil)
        return .init(
          target: target,
          authors: authors,
          randoms: [],
          participants: [],
          approves: authors.reduce(into: [:], { $0[$1] = approve }),
          thread: thread
        )
      }
      public struct Approve {
        public var commit: Git.Sha
        public var resolution: Yaml.Fusion.Approval.Status.Resolution
        public static func make(
          yaml: [String: Yaml.Fusion.Approval.Status.Resolution]
        ) throws -> Self {
          guard yaml.count == 1, let (commit, resolution) = yaml.first
          else { throw Thrown("Bad approve format") }
          return try .init(commit: .make(value: commit), resolution: resolution)
        }
      }
    }
  }
}
