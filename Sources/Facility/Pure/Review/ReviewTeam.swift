import Foundation
import Facility
extension Review {
  public struct Team {
    public var name: String
    public var quorum: Int
    public var random: Set<String>
    public var reserve: Set<String>
    public var optional: Set<String>
    public var required: Set<String>
    public var advanceApproval: Bool
    public var approvers: Set<String> { reserve.union(optional).union(required).union(random) }
    var isUnapprovable: Bool { approvers.count < quorum }
    public static func make(
      name: String,
      yaml: Yaml.Review.Rules.Team
    ) -> Self { .init(
      name: name,
      quorum: yaml.quorum,
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
      if required.isEmpty.not {
        quorum -= required.intersection(involved).count
        required = required.subtracting(involved)
      }
      if required.isEmpty {
        quorum -= optional.intersection(involved).count
        optional = optional.subtracting(involved)
      }
      if optional.isEmpty {
        quorum -= reserve.intersection(involved).count
        reserve = reserve.subtracting(involved)
      }
      if random.isEmpty.not {
        quorum -= random.intersection(involved).count
        random = random.subtracting(involved)
      }
    }
    public mutating func update(exclude: Set<String>) {
      required = required.subtracting(exclude)
      optional = optional.subtracting(exclude)
      reserve = reserve.subtracting(exclude)
      random = random.subtracting(exclude)
    }
    public func isNeeded(user: String) -> Bool {
      guard quorum > 0 else { return false }
      guard random.contains(user).not else { return true }
      guard optional.contains(user).not else { return true }
      guard optional.isEmpty else { return false }
      return reserve.contains(user)
    }
    public var necessary: Set<String> {
      let optional = optional.union(required)
      let reserve = reserve.union(optional)
      guard reserve.count > quorum else { return reserve }
      guard optional.count > quorum else { return optional }
      return required
    }
  }
}
