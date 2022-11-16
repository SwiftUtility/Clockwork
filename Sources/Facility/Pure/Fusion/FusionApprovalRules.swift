import Foundation
import Facility
extension Fusion.Approval {
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
  }
}
