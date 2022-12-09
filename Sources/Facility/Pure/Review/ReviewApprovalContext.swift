import Foundation
import Facility
extension Review.Approval {
  public struct Context {
    public var bot: String
    public var users: [String: Gitlab.User]
    public var rules: Review.Rules
    public var ownage: [String: Criteria] = [:]
    public static func make(gitlab: Gitlab, rules: Review.Rules) throws -> Self { try .init(
      bot: gitlab.rest.get().user.username,
      users: gitlab.users,
      rules: rules
    )}
  }
}
