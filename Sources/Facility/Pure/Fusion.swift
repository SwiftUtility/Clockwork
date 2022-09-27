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
        fork: .init(value: components[3]),
        prefix: components[0],
        source: .init(name: components[2]),
        target: .init(name: components[1]),
        supply: .init(name: supply)
      )
    }
  }
  public struct Queue {
    public private(set) var queue: [String: [UInt]]
    public var yaml: String {
      var result: String = ""
      for target in queue.keys.sorted() {
        guard let reviews = queue[target], !reviews.isEmpty else { continue }
        result += "'\(target)':\n"
        for review in reviews { result += "- \(review)\n" }
      }
      return result.isEmpty.else(result).get("{}\n")
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
    public var antagonists: Configuration.Secret?
    public static func make(yaml: Yaml.Fusion.Approval) throws -> Self { try .init(
      rules: .make(preset: yaml.rules),
      statuses: .make(yaml: yaml.statuses),
      approvers: .make(yaml: yaml.approvers),
      antagonists: yaml.antagonists
        .map(Configuration.Secret.make(yaml:))
    )}
    public struct Approver: Encodable {
      public var active: Bool
      public var slack: String
      public var name: String
      public static func make(yaml: Yaml.Fusion.Approval.Approver) -> Self { .init(
        active: yaml.active,
        slack: yaml.slack,
        name: yaml.name
      )}
    }
    public struct Rules {
      public var sanity: String?
      public var emergency: String?
      public var randoms: Randoms?
      public var teams: [String: Team]
      public var authorship: [String: [String]]
      public var sourceBranch: [String: Criteria]
      public var targetBranch: [String: Criteria]
      public static func make(yaml: Yaml.Fusion.Approval.Rules) throws -> Self { try .init(
        sanity: yaml.sanity,
        emergency: yaml.emergency,
        randoms: yaml.randoms
          .map(Randoms.make(yaml:)),
        teams: yaml.teams
          .get([:])
          .mapValues(Team.make(yaml:)),
        authorship: yaml.authorship
          .get([:]),
        sourceBranch: yaml.sourceBranch
          .get([:])
          .mapValues(Criteria.init(yaml:)),
        targetBranch: yaml.targetBranch
          .get([:])
          .mapValues(Criteria.init(yaml:))
      )}
      public struct Team {
        public var quorum: Int
        public var advanceApproval: Bool
        public var selfApproval: Bool
        public var ignoreAntagonism: Bool
        public var labels: [String]
        public var reserve: [String]
        public var optional: [String]
        public var required: [String]
        public static func make(yaml: Yaml.Fusion.Approval.Rules.Team) -> Self { .init(
          quorum: yaml.quorum,
          advanceApproval: yaml.advanceApproval.get(false),
          selfApproval: yaml.selfApproval.get(false),
          ignoreAntagonism: yaml.ignoreAntagonism.get(false),
          labels: yaml.labels.get([]),
          reserve: yaml.reserve.get([]),
          optional: yaml.optional.get([]),
          required: yaml.required.get([])
        )}
      }
      public struct Randoms {
        public var minQuorum: Int
        public var maxQuorum: Int
        public var baseWeight: Int
        public var weights: [String: Int]
        public var advanceApproval: Bool
        public static func make(yaml: Yaml.Fusion.Approval.Rules.Randoms) -> Self { .init(
          minQuorum: yaml.minQuorum,
          maxQuorum: yaml.maxQuorum,
          baseWeight: yaml.baseWeight,
          weights: yaml.weights
            .get([:]),
          advanceApproval: yaml.advanceApproval
        )}
      }
    }
    public struct Status {
      public var thread: Configuration.Thread
      public var target: String
      public var author: String
      public var coauthors: [String: String]
      public var review: Review?
      public static func make(yaml: Yaml.Fusion.Approval.Status) throws -> Self { try .init(
        thread: .make(yaml: yaml.thread),
        target: yaml.target,
        author: .init(yaml.author),
        coauthors: yaml.coauthors.get([:]),
        review: yaml.review.map(Review.make(yaml:))
      )}
      public static func yaml(statuses: [UInt: Self]) -> String {
        var result = ""
        for (key, value) in statuses.sorted(by: { $0.key < $1.key }) {
          result += "'\(key)':\n"
          result += "  thread:\n"
          result += "    channel: '\(value.thread.channel)'\n"
          result += "    ts: '\(value.thread.ts)'\n"
          result += "  target: '\(value.target)'\n"
          result += "  author: '\(value.author)'\n"
          if !value.coauthors.isEmpty {
            result += "  coauthors:\n"
            for (key, value) in value.coauthors.sorted(by: { $0.key < $1.key }) {
              result += "    '\(key)': '\(value)'\n"
            }
          }
          if let review = value.review {
            result += "  review:\n"
            let randoms = review.randoms.sorted().map { "'\($0)'" }.joined(separator: ",")
            result += "    randoms: [\(randoms)]\n"
            result += "    teams:\(review.teams.isEmpty.then(" {}").get(""))\n"
            for (key, value) in review.teams.sorted(by: { $0.key.value < $1.key.value }) {
              let teams = value.sorted().map { "'\($0)'" }.joined(separator: ",")
              result += "      '\(key.value)': [\(teams)]\n"
            }
            result += "    approves:\(review.approves.isEmpty.then(" {}").get(""))\n"
            for (key, value) in review.approves.sorted(by: { $0.key < $1.key }) {
              result += "      '\(key)':\n"
              result += "        commit: '\(value.commit.value)'\n"
              result += "        resolution: \(value.resolution.rawValue)\n"
            }
          }
        }
        return result.isEmpty.then("{}\n").get(result)
      }
      public static func make(
        thread: Configuration.Thread,
        target: String,
        author: String,
        coauthors: [String: String]
      ) -> Self { .init(
        thread: thread,
        target: target,
        author: author,
        coauthors: coauthors
      )}
      public struct Review {
        public var randoms: Set<String>
        public var teams: [Git.Sha: Set<String>]
        public var approves: [String: Approve]
        public static func make(yaml: Yaml.Fusion.Approval.Status.Review) throws -> Self { try .init(
          randoms: .init(yaml.randoms),
          teams: yaml.teams
            .reduce(into: [:]) { try $0[.init(value: $1.key)] = .init($1.value) },
          approves: yaml.approves
            .mapValues(Approve.make(yaml:))
        )}
        public struct Approve {
          public var commit: Git.Sha
          public var resolution: Yaml.Fusion.Approval.Status.Review.Approve.Resolution
          public static func make(yaml: Yaml.Fusion.Approval.Status.Review.Approve) throws -> Self {
            try .init(commit: .init(value: yaml.commit), resolution: yaml.resolution)
          }
        }
      }
    }
  }
}
