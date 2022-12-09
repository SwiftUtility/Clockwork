import Foundation
import Facility
extension Review {
  public struct Storage {
    public var asset: Configuration.Asset
    public var queues: [String: [UInt]]
    public var states: [UInt: State]
    public static func make(
      review: Review,
      yaml: Yaml.Review.Storage
    ) throws -> Self { try .init(
      asset: review.storage,
      queues: yaml.queues,
      states: yaml.states
        .map(State.make(review:yaml:))
        .reduce(into: [:], { $0[$1.review] = $1 })
    )}
    public struct State {
      public var review: UInt
      public var target: Git.Branch
      public var authors: Set<String>
      public var phase: Phase? = nil
      public var skip: Set<Git.Sha> = []
      public var teams: Set<String> = []
      public var emergent: Git.Sha? = nil
      public var verified: Git.Sha? = nil
      public var randoms: Set<String> = []
      public var legates: Set<String> = []
      public var replicate: Git.Branch? = nil
      public var integrate: Git.Branch? = nil
      public var duplicate: Git.Branch? = nil
      public var reviewers: [String: Reviewer] = [:]
      public var squash: Bool { replicate == nil && integrate == nil }
      mutating func block() {
        phase = .block
        emergent = nil
        verified = nil
      }
      mutating func update(target branch: Git.Branch, rules: Rules) {
        guard branch != target else { return }
        target = branch
        emergent = nil
        verified = nil
        reviewers = rules.targetBranch
          .filter({ $0.value.isMet(branch.name) })
          .compactMap({ rules.teams[$0.key]?.approvers })
          .reduce(into: Set(), { $0.formUnion($1) })
          .reduce(into: reviewers, { $0[$1]?.resolution = .obsolete })
      }
      public static func make(
        review: String,
        yaml: Yaml.Review.Storage.State
      ) throws -> Self { try .init(
        review: review.getUInt(),
        target: .make(name: yaml.target),
        authors: Set(yaml.authors),
        phase: yaml.phase.map(Phase.make(yaml:)),
        skip: Set(yaml.skip.get([]).map(Git.Sha.make(value:))),
        teams: Set(yaml.teams.get([])),
        emergent: yaml.emergent.map(Git.Sha.make(value:)),
        verified: yaml.verified.map(Git.Sha.make(value:)),
        randoms: Set(yaml.randoms.get([])),
        legates: Set(yaml.legates.get([])),
        replicate: yaml.replicate.map(Git.Branch.make(name:)),
        integrate: yaml.integrate.map(Git.Branch.make(name:)),
        reviewers: yaml.reviewers.get([:])
          .map(Reviewer.make(login:yaml:))
          .reduce(into: [:], { $0[$1.login] = $1 })
      )}
    }
    public struct Reviewer {
      public var login: String
      public var hold: Bool = false
      public var comments: Int = 0
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
      public static func make(yaml: Yaml.Review.Storage.Resolution) -> Self {
        switch yaml {
        case .fragil: return .fragil
        case .advance: return .advance
        case .obsolete: return .obsolete
        }
      }
    }
    public enum Phase: String, Encodable {
      case block
      case stuck
      case amend
      case queue
      case check
      public static func make(yaml: Yaml.Review.Storage.Phase) -> Self {
        switch yaml {
        case .block: return .block
        case .stuck: return .stuck
        case .amend: return .amend
        case .queue: return .queue
        case .check: return .check
        }
      }
    }
  }
}
