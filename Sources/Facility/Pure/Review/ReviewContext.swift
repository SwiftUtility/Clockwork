import Foundation
import Facility
extension Review {
  public struct Context {
    public var bots: Set<String>
    public var users: [String: Gitlab.Storage.User]
    public var rules: Review.Rules
    public var ownage: [String: Criteria]
    public var profile: Configuration.Profile
    public static func make(
      gitlab: Gitlab,
      rules: Review.Rules,
      ownage: [String: Criteria],
      profile: Configuration.Profile
    ) throws -> Self { try .init(
      bots: gitlab.storage.bots.union([gitlab.rest.get().user.username]),
      users: gitlab.storage.users,
      rules: rules,
      ownage: ownage,
      profile: profile
    )}
    func check(
      state: Storage.State,
      fusion: Fusion
    ) -> [Update.Blocker] {
      var result: [Update.Blocker] = []
      if let sanity = rules.sanity {
        if
          let sanity = ownage[sanity],
          let codeOwnage = profile.codeOwnage,
          sanity.isMet(profile.location.path.value),
          sanity.isMet(codeOwnage.path.value)
        {} else { result.append(.sanity(sanity)) }
      }
      let unknownUsers = state.authors
        .union(state.reviewers.keys)
        .union(rules.ignore.keys)
        .union(rules.ignore.flatMap(\.value))
        .union(rules.authorship.flatMap(\.value))
        .union(rules.teams.flatMap(\.value.approvers))
        .union(rules.teams.flatMap(\.value.random))
        .subtracting(users.keys)
        .subtracting(bots)
      if unknownUsers.isEmpty.not { result.append(.unknownUsers(unknownUsers)) }
      let unknownTeams = Set(rules.sanity.array)
        .union(ownage.keys)
        .union(rules.targetBranch.keys)
        .union(rules.sourceBranch.keys)
        .union(rules.authorship.keys)
        .union(rules.randoms.keys)
        .union(rules.randoms.flatMap(\.value))
        .filter({ rules.teams[$0] == nil })
      if unknownTeams.isEmpty.not { result.append(.unknownTeams(unknownTeams)) }
      var confusedTeams = ownage.keySet
        .union(rules.sanity.array)
        .union(rules.targetBranch.keys)
        .union(rules.sourceBranch.keys)
        .union(rules.authorship.keys)
        .union(rules.randoms.flatMap(\.value))
        .compactMap({ rules.teams[$0] })
        .filter({ $0.random.isEmpty.not })
      confusedTeams += rules.randoms.keys
        .compactMap({ rules.teams[$0] })
        .filter({ $0.approvers.isEmpty.not })
      if confusedTeams.isEmpty.not
      { result.append(.confusedTeams(Set(confusedTeams.map(\.name)))) }
      let active = users.values.filter(\.active).map(\.login)
      if fusion.allowOrphaned.not, state.authors.intersection(active).isEmpty
      { result.append(.orphaned(state.authors)) }

      return result
    }
  }
}
