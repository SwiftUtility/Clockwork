import Foundation
import Facility
extension Fusion.Approval.Rules {
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
      required = required
        .intersection(active)
      optional = optional
        .intersection(active)
        .subtracting(required)
      reserve = reserve
        .intersection(active)
        .subtracting(required)
        .subtracting(optional)
      random.formIntersection(active)
    }
    public mutating func update(involved: Set<String>) {
      #warning("tbd")
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
