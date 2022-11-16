import Foundation
import Facility
extension Fusion {
  public struct Approval {
    public var rules: Configuration.Secret
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
    public struct Status {
      public var review: UInt
      public var target: String
      public var skip: Set<Git.Sha>
      public var teams: Set<String>
      public var emergent: Git.Sha?
      public var verified: Git.Sha?
      public var authors: Set<String>
      public var randoms: Set<String>
      public var legates: Set<String>
      public var approves: [String: Approve]
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
        skip: Set(yaml.skip.get([]).map(Git.Sha.make(value:))),
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
          let skip = status.skip.map(\.value).sorted().map({ "'\($0)'" }).joined(separator: ",")
          if skip.isEmpty.not { result += "  skip: [\(skip)]\n" }
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
        fork: Git.Sha?
      ) -> Self { .init(
        review: review,
        target: target,
        skip: [],
        teams: [],
        emergent: nil,
        authors: authors,
        randoms: [],
        legates: [],
        approves: makeApproves(fork: fork, authors: authors)
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
