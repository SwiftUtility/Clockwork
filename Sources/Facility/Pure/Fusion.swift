import Foundation
import Facility
public struct Fusion {
  public var approval: Approval
  public var proposition: Proposition
  public var replication: Replication
  public var integration: Integration
  public var queue: Configuration.Asset
  public var createThread: Configuration.Template
  func createCommitMessage(kind: Kind) -> Configuration.Template {
    switch kind {
    case .proposition: return proposition.createCommitMessage
    case .replication: return replication.createCommitMessage
    case .integration: return integration.createCommitMessage
    }
  }
  public func makeKind(state: Json.GitlabReviewState, project: Json.GitlabProject) throws -> Kind {
    guard let merge = Merge.make(source: state.sourceBranch, project: project) else {
      let rules = proposition.rules.filter { $0.source.isMet(state.sourceBranch) }
      guard rules.count < 2
      else { throw Thrown("\(state.sourceBranch) matches multiple proposition rules") }
      return try .proposition(.init(
        target: .init(name: state.targetBranch),
        source: .init(name: state.sourceBranch),
        rule: rules.first
      ))
    }
    switch merge.prefix {
    case .replicate: return .replication(merge)
    case .integrate: return .integration(merge)
    }
  }
  public static func make(
    yaml: Yaml.Review
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
      exportAvailableTargets: .make(yaml: yaml.integration.exportTargets)
    ),
    queue: .make(yaml: yaml.queue),
    createThread: .make(yaml: yaml.createThread)
  )}
  public enum Kind {
    case proposition(Proposition.Merge)
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
      default: return false
      }
    }
    public var target: Git.Branch {
      switch self {
      case .proposition(let merge): return merge.target
      case .replication(let merge), .integration(let merge): return merge.target
      }
    }
    public var source: Git.Branch {
      switch self {
      case .proposition(let merge): return merge.source
      case .replication(let merge), .integration(let merge): return merge.source
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
    public struct Merge {
      public let target: Git.Branch
      public let source: Git.Branch
      public var rule: Rule?

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
    public let prefix: Prefix
    public let subject: Git.Branch
    public let target: Git.Branch
    public let source: Git.Branch
    public static func makeIntegration(
      fork: Git.Sha,
      subject: Git.Branch,
      target: Git.Branch
    ) throws -> Self {
      let components = [Prefix.integrate.rawValue, target.name, subject.name, fork.value]
      return try .init(
        fork: fork,
        prefix: .integrate,
        subject: subject,
        target: target,
        source: .init(name: components.joined(separator: "/-/"))
      )
    }
    public static func makeReplication(
      fork: Git.Sha,
      subject: Git.Branch,
      project: Json.GitlabProject
    ) throws -> Self {
      let components = [Prefix.replicate.rawValue, subject.name, fork.value]
      return try .init(
        fork: fork,
        prefix: .replicate,
        subject: subject,
        target: .init(name: project.defaultBranch),
        source: .init(name: components.joined(separator: "/-/"))
      )
    }
    public static func make(source: String, project: Json.GitlabProject) -> Self? {
      let components = source.components(separatedBy: "/-/")
      guard let prefix = components.first.flatMap(Prefix.init(rawValue:)) else { return nil }
      switch prefix {
      case .replicate:
        guard components.count == 3 else { return nil }
        return try? .init(
          fork: .make(value: components[2]),
          prefix: prefix,
          subject: .init(name: components[1]),
          target: .init(name: project.defaultBranch),
          source: .init(name: source)
        )
      case .integrate:
        guard components.count == 4 else { return nil }
        return try? .init(
          fork: .make(value: components[3]),
          prefix: prefix,
          subject: .init(name: components[2]),
          target: .init(name: components[1]),
          source: .init(name: source)
        )
      }
    }
    public enum Prefix: String {
      case replicate
      case integrate
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
    public var rules: Configuration.Asset
    public var statuses: Configuration.Asset
    public var approvers: Configuration.Asset
    public var haters: Configuration.Secret?
    public static func make(yaml: Yaml.Review.Approval) throws -> Self { try .init(
      rules: .make(yaml: yaml.rules),
      statuses: .make(yaml: yaml.statuses),
      approvers: .make(yaml: yaml.approvers),
      haters: yaml.haters
        .map(Configuration.Secret.make(yaml:))
    )}
    public struct Approver: Encodable {
      public var login: String
      public var active: Bool
      public var chat: String
      public var watchTeams: Set<String>
      public var watchAuthors: Set<String>
      public static func serialize(approvers this: [String: Self]) -> String {
        guard this.isEmpty.not else { return "{}" }
        var result: String = ""
        for approvar in this.keys.sorted().compactMap({ this[$0] }) {
          result += "'\(approvar.login)':\n"
          result += "  active: \(approvar.active)\n"
          result += "  chat: \(approvar.chat)\n"
          let watchTeams = approvar.watchTeams.sorted().map({ "'\($0)'" }).joined(separator: ",")
          if watchTeams.isEmpty.not { result += "  watchTeams: [\(watchTeams)]\n" }
          let watchAuthors = approvar.watchAuthors.sorted().map({ "'\($0)'" }).joined(separator: ",")
          if watchAuthors.isEmpty.not { result += "  watchAuthors: [\(watchAuthors)]\n" }
        }
        return result
      }
      public static func make(login: String, yaml: Yaml.Review.Approval.Approver) -> Self { .init(
        login: login,
        active: yaml.active,
        chat: yaml.chat,
        watchTeams: Set(yaml.watchTeams.get([])),
        watchAuthors: Set(yaml.watchAuthors.get([]))
      )}
      public static func make(login: String, active: Bool, slack: String) -> Self { .init(
        login: login,
        active: active,
        chat: slack,
        watchTeams: [],
        watchAuthors: []
      )}
      public enum Command {
        case activate
        case deactivate
        case register(String)
        case unwatchAuthors([String])
        case unwatchTeams([String])
        case watchAuthors([String])
        case watchTeams([String])
        public var reason: Generate.CreateApproversCommitMessage.Reason {
          switch self {
          case .activate: return .activate
          case .deactivate: return .deactivate
          case .register: return .register
          case .unwatchAuthors: return .unwatchAuthors
          case .unwatchTeams: return .unwatchTeams
          case .watchAuthors: return .watchAuthors
          case .watchTeams: return .watchTeams
          }
        }
      }
    }
    public struct Rules {
      public var sanity: String?
      public var weights: [String: Int]
      public var baseWeight: Int
      public var teams: [String: Team]
      public var randoms: [String: Set<String>]
      public var authorship: [String: Set<String>]
      public var sourceBranch: [String: Criteria]
      public var targetBranch: [String: Criteria]
      public static func make(yaml: Yaml.Review.Approval.Rules) throws -> Self { try .init(
        sanity: yaml.sanity,
        weights: yaml.weights.get([:]),
        baseWeight: yaml.baseWeight,
        teams: yaml.teams
          .get([:])
          .map(Team.make(name:yaml:))
          .reduce(into: [:], { $0[$1.name] = $1 }),
        randoms: yaml.randoms.get([:])
          .mapValues(Set.init(_:)),
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
        public var name: String
        public var quorum: Int
        public var labels: [String]
        public var random: Set<String>
        public var reserve: Set<String>
        public var optional: Set<String>
        public var required: Set<String>
        public var advanceApproval: Bool
        public var approvers: Set<String> { reserve.union(optional).union(required) }
        public static func make(
          name: String,
          yaml: Yaml.Review.Approval.Rules.Team
        ) -> Self { .init(
          name: name,
          quorum: yaml.quorum,
          labels: yaml.labels.get([]),
          random: Set(yaml.random.get([])),
          reserve: Set(yaml.reserve.get([])),
          optional: Set(yaml.optional.get([])),
          required: Set(yaml.required.get([])),
          advanceApproval: yaml.advance.get(false)
        )}
        public mutating func update(active: Set<String>) {
          required.formIntersection(active)
          optional.formIntersection(active)
          reserve.formIntersection(active)
          random.formIntersection(active)
        }
        public mutating func update(involved: Set<String>) {
          quorum -= approvers
            .union(random)
            .intersection(involved)
            .count
          update(exclude: involved)
        }
        public mutating func update(exclude: Set<String>) {
          required = required.subtracting(exclude)
          optional = optional.subtracting(exclude)
          reserve = reserve.subtracting(exclude)
          random = random.subtracting(exclude)
        }
        public mutating func update(optional involved: Set<String>) {
          let involved = reserve.intersection(involved)
          optional = optional.union(involved)
          reserve = reserve.subtracting(involved)
        }
        public mutating func update(isRandom: Bool) {
          if isRandom {
            required = []
            optional = []
            reserve = []
          } else {
            random = []
          }
        }
        public func isNeeded(user: String) -> Bool {
          guard quorum > 0 else { return false }
          return required.contains(user)
          || optional.contains(user)
          || reserve.contains(user)
          || random.contains(user)
        }
        public var necessary: Set<String> {
          let optional = optional.union(required)
          let reserve = reserve.union(optional)
          guard reserve.count > quorum else { return reserve }
          guard optional.count > quorum else { return optional }
          return []
        }
      }
    }
    public struct Status {
      public var review: UInt
      public var target: String
      public var teams: Set<String>
      public var emergent: Git.Sha?
      public var verified: Git.Sha?
      public var authors: Set<String>
      public var randoms: Set<String>
      public var legates: Set<String>
      public var approves: [String: Approve]
      public var thread: Configuration.Thread
      mutating func invalidate(users: Set<String>) { approves
        .filter(\.value.resolution.approved)
        .keys
        .filter(users.contains(_:))
        .forEach { approves[$0]?.resolution = .outdated }
      }
      public var approvedCommits: Set<Git.Sha> { approves.values
        .filter(\.resolution.approved)
        .reduce(into: Set(emergent.array), { $0.insert($1.commit) })
      }
      public func reminds(sha: String, approvers: [String: Approver]) -> Set<String> {
        guard emergent == nil else { return [] }
        guard verified?.value == sha else { return [] }
        return legates
          .union(randoms)
          .union(authors)
          .union(approves.filter(\.value.resolution.block).keys)
          .subtracting(approves.filter(\.value.resolution.approved).keys)
          .intersection(approvers.filter(\.value.active).keys)
      }
      public func isWatched(by approver: Approver) -> Bool {
        guard teams.isDisjoint(with: approver.watchTeams) else { return true }
        guard authors.isDisjoint(with: approver.watchAuthors) else { return true }
        return false
      }
      public static func make(
        review: String,
        yaml: Yaml.Review.Approval.Status
      ) throws -> Self { try .init(
        review: review.getUInt(),
        target: yaml.target,
        teams: Set(yaml.teams.get([])),
        emergent: yaml.emergent.map(Git.Sha.make(value:)),
        verified: yaml.verified.map(Git.Sha.make(value:)),
        authors: Set(yaml.authors),
        randoms: Set(yaml.randoms.get([])),
        legates: Set(yaml.legates.get([])),
        approves: yaml.approves.get([:])
          .map(Approve.make(approver:yaml:))
          .reduce(into: [:], { $0[$1.approver] = $1 }),
        thread: .make(yaml: yaml.thread)
      )}
      public static func serialize(statuses: [UInt: Self]) -> String {
        var result = ""
        for (review, status) in statuses.sorted(by: { $0.key < $1.key }) {
          result += "'\(review)':\n"
          result += "  thread: \(status.thread.serialize())\n"
          result += "  target: '\(status.target)'\n"
          let authors = status.authors
            .sorted()
            .map({ "'\($0)'" })
            .joined(separator: ",")
          result += "  authors: [\(authors)]\n"
          let teams = status.teams.sorted().map({ "'\($0)'" }).joined(separator: ",")
          if teams.isEmpty.not { result += "  teams: [\(teams)]\n" }
          if let verified = status.verified?.value { result += "  verified: '\(verified)'\n" }
          if let emergent = status.emergent?.value { result += "  emergent: '\(emergent)'\n" }
          let legates = status.legates.sorted().map { "'\($0)'" }.joined(separator: ",")
          if legates.isEmpty.not { result += "  legates: [\(legates)]\n" }
          let randoms = status.randoms.sorted().map { "'\($0)'" }.joined(separator: ",")
          if randoms.isEmpty.not { result += "  randoms: [\(randoms)]\n" }
          let approves = status.approves.keys
            .sorted()
            .compactMap({ status.approves[$0] })
            .map({ "    '\($0.approver)': {\($0.resolution.rawValue): '\($0.commit.value)'}\n" })
          if approves.isEmpty.not { result += "  approves:\n" + approves.joined() }
        }
        return result.isEmpty.then("{}\n").get(result)
      }
      public static func make(
        review: UInt,
        target: String,
        authors: Set<String>,
        thread: Configuration.Thread,
        fork: Git.Sha?
      ) -> Self { .init(
        review: review,
        target: target,
        teams: [],
        emergent: nil,
        authors: authors,
        randoms: [],
        legates: [],
        approves: makeApproves(fork: fork, authors: authors),
        thread: thread
      )}
      public static func makeApproves(fork: Git.Sha?, authors: Set<String>) -> [String: Approve] {
        guard let fork = fork else { return [:] }
        return authors
          .map({ .init(approver: $0, commit: fork, resolution: .fragil) })
          .reduce(into: [:], { $0[$1.approver] = $1 })
      }
      public enum Resolution: String {
        case block
        case fragil
        case advance
        case outdated
        public var approved: Bool {
          switch self {
          case .fragil, .advance: return true
          case .block, .outdated: return false
          }
        }
        public var fragil: Bool {
          switch self {
          case .fragil: return true
          default: return false
          }
        }
        public var block: Bool {
          switch self {
          case .block: return true
          default: return false
          }
        }
        public var outdated: Bool {
          switch self {
          case .outdated: return true
          default: return false
          }
        }
      }
      public struct Approve {
        public var approver: String
        public var commit: Git.Sha
        public var resolution: Resolution
        public static func make(
          approver: String,
          yaml: [String: String]
        ) throws -> Self {
          guard yaml.count == 1, let yaml = yaml.first else { throw Thrown("Bad approve format") }
          return try .init(
            approver: approver,
            commit: .make(value: yaml.value),
            resolution:  .init(rawValue: yaml.key)
              .get { throw Thrown("Bad resolution format") }
          )
        }
      }
    }
  }
}
