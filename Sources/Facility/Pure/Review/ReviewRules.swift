import Foundation
import Facility
extension Review {
  public struct Rules {
    public var hold: String
    public var baseWeight: Int
    public var sanity: String?
    public var weights: [String: Int]
    public var teams: [String: Team]
    public var randoms: [String: Set<String>]
    public var ignore: [String: Set<String>]
    public var authorship: [String: Set<String>]
    public var sourceBranch: [String: Criteria]
    public var targetBranch: [String: Criteria]
    public static func make(yaml: Yaml.Review.Rules) throws -> Self { try .init(
      hold: yaml.hold,
      baseWeight: yaml.baseWeight,
      sanity: yaml.sanity,
      weights: yaml.weights.get([:]),
      teams: yaml.teams.get([:]).map(Team.make(name:yaml:)).indexed(\.name),
      randoms: yaml.randoms.get([:]),
      ignore: yaml.ignore.get([:]),
      authorship: yaml.authorship.get([:]),
      sourceBranch: yaml.sourceBranch.get([:]).mapValues(Criteria.init(yaml:)),
      targetBranch: yaml.targetBranch.get([:]).mapValues(Criteria.init(yaml:))
    )}
  }
}
