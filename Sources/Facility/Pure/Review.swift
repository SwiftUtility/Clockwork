import Foundation
import Facility
public struct Review {
  public let bot: String
  public let approvers: [String: Fusion.Approval.Approver]
  public let kind: Fusion.Kind
  public let ownage: [String: Criteria]
  public let rules: Fusion.Approval.Rules
  public let haters: [String: Set<String>]
  public internal(set) var status: Fusion.Approval.Status
  public internal(set) var utilityTeams: Set<String> = []
  public internal(set) var changedTeams: [Git.Sha: Set<String>] = [:]
  public internal(set) var diffTeams: Set<String> = []
  public internal(set) var childCommits: [Git.Sha: Set<Git.Sha>] = [:]
  public static func make(
    gitlabCi: GitlabCi,
    statuses: [UInt: Fusion.Approval.Status],
    approvers: [String: Fusion.Approval.Approver],
    review: Json.GitlabReviewState,
    kind: Fusion.Kind,
    ownage: [String: Criteria],
    rules: Fusion.Approval.Rules,
    haters: [String: Set<String>]
  ) throws -> Self {
    let unknownTeams = Set(rules.emergency.array + rules.sanity.array)
      .union(ownage.keys)
      .union(rules.targetBranch.keys)
      .union(rules.sourceBranch.keys)
      .union(rules.authorship.keys)
      .filter { rules.teams[$0] == nil }
      .joined(separator: ", ")
    guard unknownTeams.isEmpty else { throw Thrown("Unknown teams: \(unknownTeams)") }
    let status = try statuses[review.iid].get { throw Thrown("No review status in asset") }
    var result = try Self(
      bot: gitlabCi.protected.get().user.username,
      approvers: approvers,
      kind: kind,
      ownage: ownage,
      rules: rules,
      haters: haters,
      status: status
    )
    let targetTeams = Set(rules.targetBranch.filter({ $0.value.isMet(review.targetBranch) }).keys)
    if result.status.target != review.targetBranch {
      result.status.invalidate(users: targetTeams
        .compactMap({ rules.teams[$0] })
        .reduce(Set(), { $0.union($1.approvers) })
      )
    }
    result.utilityTeams = kind.proposition.then(rules.authorship).get([:])
      .filter({ !$0.value.intersection(status.authors).isEmpty })
      .reduce(into: Set(), { $0.insert($1.key) })
      .union(rules.sourceBranch.filter({ $0.value.isMet(review.sourceBranch) }).keys)
      .union(targetTeams)
    result.status.target = review.targetBranch
    return result
  }
  public mutating func addDiff(files: [String]) {
    for (team, criteria) in ownage {
      if files.contains(where: criteria.isMet(_:)) { diffTeams.insert(team) }
    }
  }
  public mutating func addBreakers(sha: Git.Sha, commits: [String]?) throws {
    if let commits = commits { childCommits[sha] = try Set(commits.map(Git.Sha.init(value:))) }
    else { status.invalidate(users: Set(status.approves.filter({ $0.value.commit == sha }).keys)) }
  }
  public mutating func addChanges(sha: Git.Sha, files: [String]) {
    changedTeams[sha] = diffTeams
      .intersection(ownage.filter({ files.contains(where: $0.value.isMet(_:)) }).keys)
  }
  public mutating func setAuthor(user: String) throws {
    guard !status.authors.contains(user) else { return }
    status.authors = [user]
    guard kind.proposition else { return }
    status.invalidate(users: rules.authorship
      .filter({ $0.value.contains(user) })
      .compactMap({ rules.teams[$0.key] })
      .reduce(into: [], { $0.formUnion($1.approvers) })
    )
  }
  public mutating func updateApproval() -> Approval {
    var approval = Approval()
    let approves = resolveApproves()
    updateParticipants(approves: approves)
    approval.troubles = resolveTroubles()
    #warning("calc update")
    return approval
  }
  func resolveApproves() -> [String: Yaml.Fusion.Approval.Status.Resolution] {
    var result = status.approves
      .reduce(into: [:], { $0[$1.key] = $1.value.resolution })
    let cheaters = Set(status.approves.filter(\.value.resolution.emergent).keys)
    let fragilUtilityTeamUsers = rules.teams
      .filter({ utilityTeams.contains($0.key) })
      .filter(\.value.advanceApproval.not)
      .reduce(into: Set(), { $0.formUnion($1.value.approvers) })
      .subtracting(cheaters)
    let fragilUsers = cheaters.isEmpty
      .else(make: { rules.emergency
        .flatMap({ rules.teams[$0] })
        .filter(isIncluded: \.advanceApproval.not)
        .map(\.approvers)
        .get([])
        .intersection(cheaters)
      })
      .get([])
      .union(status.approves.filter(\.value.resolution.fragil).keys)
      .union(status.authors)
      .union(fragilUtilityTeamUsers)
    let fragilDiffTeams = diffTeams
        .compactMap({ rules.teams[$0]?.advanceApproval.else($0) })
    let advanceDiffTeams = Set(diffTeams.compactMap({ rules.teams[$0]?.advanceApproval.then($0) }))
    for (sha, childs) in childCommits {
      let brokenTeams = childs
        .compactMap({ changedTeams[$0] })
        .reduce(into: Set(), { $0.formUnion($1) })
      let invalids: Set<String> = brokenTeams.isEmpty.then([]) ?? changedTeams
        .compactMap({ childs.contains($0.key).not.then($0.value) })
        .reduce(advanceDiffTeams, { $0.subtracting($1) })
        .union(fragilDiffTeams)
        .intersection(brokenTeams)
        .reduce(into: Set(), { $0.formUnion(rules.teams[$1]?.approvers ?? []) })
        .subtracting(cheaters)
        .union(fragilUsers)
      result = status.approves
        .filter({ $0.value.commit == sha })
        .filter({ invalids.contains($0.key) })
        .reduce(into: result, { $0[$1.key] = $1.value.resolution })
    }
    return result
  }
  mutating func updateParticipants(
    approves: [String: Yaml.Fusion.Approval.Status.Resolution]
  ) {
    let active = Set(approvers.filter(\.value.active).keys)
      .union(approves.filter(\.value.approved).keys)
    status.participants = status.participants.intersection(active)
    status.participants = status.participants.subtracting(status.authors)
    var teams = diffTeams.union(utilityTeams)
      .reduce(into: [:], { $0[$1] = rules.teams[$1] })
    teams = teams.reduce(into: teams, { $0[$1.key]?.update(active: active) })
    let required = teams.values.reduce(Set(), { $0.union($1.required) })
    if kind.proposition {
      let exclude = Set(haters.filter({ $0.value.intersection(status.authors).isEmpty.not }).keys)
        .subtracting(required)
        .union(status.authors)
      teams = teams.reduce(into: teams, { $0[$1.key]?.update(exclude: exclude) })
    } else {
      teams = teams.reduce(into: teams, { $0[$1.key]?.update(involved: status.authors) })
    }
    status.participants = status.participants
      .union(required)
      .subtracting(status.authors)
    teams = teams.reduce(into: teams, { $0[$1.key]?.update(involved: status.participants) })
    let optional = teams.values.reduce(into: Set(), { $0.formUnion($1.optional) })
    teams = teams.reduce(into: teams, { $0[$1.key]?.update(optional: optional) })
    let necessary = teams.reduce(into: Set(), { $0.formUnion($1.value.necessary) })
    teams = teams
      .reduce(into: teams, { $0[$1.key]?.update(involved: necessary) })
      .filter(\.value.approvers.isEmpty.not)
    let reserveTeams = teams.filter({ $0.value.optional.isEmpty && $0.value.quorum > 0 })
    let reserveRandom = selectUsers(
      teams: reserveTeams,
      users: reserveTeams.values.reduce(into: Set(), { $0.formUnion($1.reserve) })
    )
    teams = teams.reduce(into: teams, { $0[$1.key]?.update(involved: reserveRandom) })
    let optionalTeams = teams.filter({ $0.value.optional.isEmpty.not && $0.value.quorum > 0 })
    let optionalRandom = selectUsers(
      teams: optionalTeams,
      users: optionalTeams.values.reduce(into: Set(), { $0.formUnion($1.optional) })
    )
    status.participants = status.participants
      .union(optionalRandom)
      .union(reserveRandom)
      .union(necessary)
    
  }
  func resolveTroubles() -> Approval.Troubles? {
    var result = Approval.Troubles()
    let activeApprovers = Set(approvers.filter(\.value.active).keys)
    result.inactiveAuthors = status.authors
      .intersection(activeApprovers)
      .isEmpty
      .then(status.authors)
      .get([])
    result.unapprovalbeTeams = Set(rules.teams
      .filter({ $0.value.approvers.intersection(activeApprovers).count < $0.value.quorum })
      .keys
    )
    result.unknownUsers = status.authors
      .union(status.approves.keys)
      .union(haters.keys)
      .union(haters.flatMap(\.value))
      .union(rules.authorship.flatMap(\.value))
      .union(rules.teams.flatMap(\.value.approvers))
      .subtracting(approvers.keys)
    return result.isEmpty.else(result)
  }
  func selectUsers(teams: [String: Fusion.Approval.Rules.Team], users: Set<String>) -> Set<String> {
    var left = users
    var teams = teams.filter({ $0.value.optional.isEmpty })
    while true {
      let counts = teams
        .filter({ $0.value.quorum > 0 })
        .reduce(into: [:], { $0.merge(
          .init(uniqueKeysWithValues: $1.value.approvers
            .intersection(left)
            .map({ ($0, 1) })
          ),
          uniquingKeysWith: { $0 + $1 }
        )})
        .reduce(into: [:], { $0.merge(
          [$1.value: Set([$1.key])],
          uniquingKeysWith: { $0.union($1) })
        })
      let user = Set(random(users: counts.keys.max().flatMap({ counts[$0] }).get([])).array)
      guard user.isEmpty.not else { return users.subtracting(left) }
      left = left.subtracting(user)
      teams = teams.reduce(into: teams, { $0[$1.key]?.update(involved: user) })
    }
  }
  func random(users: Set<String>) -> String? {
    guard users.count > 1 else { return users.first }
    let users = users
      .reduce(into: [:], { $0[$1] = rules.randoms.weights[$1].get(rules.randoms.baseWeight) })
    var acc = users.map(\.value).reduce(0, +)
    if acc > 0 {
      acc = Int.random(in: 0 ..< acc)
      return users.keys.sorted().first(where: {
        acc -= users[$0].get(0)
        return acc < 0
      })
    } else {
      acc = Int.random(in: 0 ..< users.count)
      return users.keys.sorted().first(where: { _ in
        acc -= 1
        return acc < 0
      })
    }
  }
  public struct Approval {
    public var update: Update = .init()
    public var troubles: Troubles? = nil
    public struct Troubles {
      public var inactiveAuthors: Set<String> = []
      public var unapprovalbeTeams: Set<String> = []
      public var unknownUsers: Set<String> = []
      public var isEmpty: Bool {
        inactiveAuthors.isEmpty && unapprovalbeTeams.isEmpty && unknownUsers.isEmpty
      }
    }
    public struct Update: Equatable {
      public var teams: Set<String> = []
      public var addLabels: Set<String> = []
      public var delLabels: Set<String> = []
      public var blockers: Set<String> = []
      public var slackers: Set<String> = []
      public var approvers: Set<String> = []
      public var watchers: Set<String> = []
      public var notifiers: Set<String> = []
      public var cheaters: Set<String> = []
      public var outdaters: [String: Set<String>] = [:]
      public var state: State = .waitingSlackers
      public enum State: String {
        case emergent
        case approved
        case waitingAuthors
        case waitingHolders
        case waitingSlackers
        public var isApproved: Bool {
          switch self {
          case .emergent, .approved: return true
          case .waitingAuthors, .waitingHolders, .waitingSlackers: return false
          }
        }
      }
    }
  }
}
