import Foundation
import Facility
extension Review {
  public struct Storage {
    public var asset: Configuration.Asset
    public var queues: [String: [UInt]]
    public var states: [UInt: State]
    public static func make(
      fusion: Fusion,
      yaml: Yaml.Review.Storage
    ) throws -> Self { try .init(
      asset: fusion.storage,
      queues: yaml.queues,
      states: yaml.states
        .map(State.make(review:yaml:))
        .reduce(into: [:], { $0[$1.review] = $1 })
    )}
    public struct State {
      public var review: UInt
      public var target: Git.Branch
      public var authors: Set<String>
      public var status: Yaml.Review.Storage.Status? = nil
      public var skip: Set<Git.Sha> = []
      public var teams: Set<String> = []
      public var emergent: Git.Sha? = nil
      public var verified: Git.Sha? = nil
      public var randoms: Set<String> = []
      public var legates: Set<String> = []
      public var replicate: Git.Branch? = nil
      public var integrate: Git.Branch? = nil
      public var reviewers: [String: Reviewer] = [:]
      public static func make(
        review: String,
        yaml: Yaml.Review.Storage.State
      ) throws -> Self { try .init(
        review: review.getUInt(),
        target: .make(name: yaml.target),
        authors: Set(yaml.authors),
        status: yaml.status,
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
      public var comments: Int
      public var commit: Git.Sha?
      public var resolution: Yaml.Review.Storage.Resolution?
      public static func make(
        login: String,
        yaml: Yaml.Review.Storage.Reviewer
      ) throws -> Self { try .init(
        login: login,
        comments: yaml.comments.get(0),
        commit: yaml.commit.map(Git.Sha.make(value:)),
        resolution: yaml.resolution
      )}
    }
  }
}
