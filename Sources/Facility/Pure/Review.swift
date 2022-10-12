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
    bot: String,
    status: Fusion.Approval.Status,
    approvers: [String: Fusion.Approval.Approver],
    review: Json.GitlabReviewState,
    kind: Fusion.Kind,
    ownage: [String: Criteria],
    rules: Fusion.Approval.Rules,
    haters: [String: Set<String>]
  ) -> Self {
    var result = Self(
      bot: bot,
      approvers: approvers,
      kind: kind,
      ownage: ownage,
      rules: rules,
      haters: haters,
      status: status
    )
    let emergencyApprovers = rules.emergency
      .flatMap({ rules.teams[$0]?.approvers })
      .get([])
    let cheaters = status.approves.filter(\.value.resolution.emergent).keys
    result.status.invalidate(users: Set(cheaters).subtracting(emergencyApprovers))
    let authorshipTeams = kind.proposition
      .then(rules.authorship)
      .get([:])
      .filter({ $0.value.intersection(status.authors).isEmpty.not })
      .reduce(into: Set(), { $0.insert($1.key) })
    let sourceTeams = rules.sourceBranch.filter({ $0.value.isMet(review.sourceBranch) }).keys
    let targetTeams = rules.targetBranch.filter({ $0.value.isMet(review.targetBranch) }).keys
    result.utilityTeams = authorshipTeams
      .union(sourceTeams)
      .union(targetTeams)
    if result.status.target != review.targetBranch {
      result.status.invalidate(users: Set(targetTeams
        .flatMap({ rules.teams[$0].map(\.approvers).get([]) })
      ))
      result.status.target = review.targetBranch
    }
    return result
  }
  public mutating func approve(
    job: Json.GitlabJob,
    resolution: Yaml.Fusion.Approval.Status.Resolution
  ) throws {
    let user = try getUser(job: job)
    if case .emergent = resolution {
      guard let team = rules.emergency.flatMap({ rules.teams[$0] })
      else { throw Thrown("Emergency team not configured") }
      guard team.approvers.contains(user)
      else { throw Thrown("Not emergency approver: \(user)") }
    }
    status.approves[user] = try .init(
      approver: user,
      commit: .make(job: job),
      resolution: resolution
    )
  }
  public mutating func resetVerification() {
    status.verification = nil
    status.teams = []
    status.invalidate(users: Set(status.approves.keys))
    Fusion.Approval.Status
      .makeApproves(fork: kind.merge?.fork, authors: status.authors)
      .values
      .forEach({ status.approves[$0.approver] = $0 })
  }
  public mutating func prepareVerification(files: [String]) {
    diffTeams = Set(ownage.filter({ files.contains(where: $0.value.isMet(_:)) }).keys)
    status.invalidate(users: diffTeams
      .subtracting(status.teams)
      .compactMap({ rules.teams[$0] })
      .reduce(into: Set(), { $0.formUnion($1.approvers) })
      .subtracting(status.approves.filter(\.value.resolution.emergent).keys)
    )
    status.teams = diffTeams.union(utilityTeams)
  }
  public mutating func addBreakers(sha: Git.Sha, commits: [String]) throws {
    childCommits[sha] = try Set(commits.map(Git.Sha.make(value:)))
  }
  public mutating func addChanges(sha: Git.Sha, files: [String]) { changedTeams[sha] = diffTeams
    .filter({ ownage[$0]
      .map({ files.contains(where: $0.isMet(_:)) })
      .get(false)
    })
  }
  public mutating func performVerification(sha: Git.Sha) -> Troubles? {
    let cheaters = Set(status.approves.filter(\.value.resolution.emergent).keys)
    let fragilCheaters = rules.emergency
      .flatMap({ rules.teams[$0]?.advanceApproval.not.then(cheaters) })
      .get([])
    let fragilUtilityTeamUsers = rules.teams.keys
      .filter(utilityTeams.contains(_:))
      .compactMap({ rules.teams[$0] })
      .filter(\.advanceApproval.not)
      .reduce(into: Set(), { $0.formUnion($1.approvers) })
      .subtracting(cheaters)
    let fragilUsers = fragilCheaters
      .union(fragilUtilityTeamUsers)
      .union(status.authors.subtracting(cheaters))
      .union(status.approves.filter(\.value.resolution.fragil).keys)
    let fragilDiffTeamsApprovers = diffTeams.reduce(into: [:], { $0[$1] = rules.teams[$1]
      .filter(isIncluded: \.advanceApproval.not)?
      .approvers
    })
    for (sha, childs) in childCommits {
      let brokenTeams = childs
        .compactMap({ changedTeams[$0] })
        .reduce(into: Set(), { $0.formUnion($1) })
      guard brokenTeams.isEmpty.not else { continue }

      let approvers = status.approves.values
        .filter({ $0.commit == sha && $0.resolution.approved })
        .map(\.approver)
      status.invalidate(users: brokenTeams
        .reduce(into: fragilUsers, { $0.formUnion(fragilDiffTeamsApprovers[$1].get([])) })
        .intersection(approvers)
      )
    }
    if let troubles = chechTroubles() { return troubles } else {
      status.verification = sha
      return nil
    }
  }
  public mutating func setAuthor(job: Json.GitlabJob) throws {
    let user = try getUser(job: job)
    status.authors.insert(user)
    guard kind.proposition else { return }
    status.invalidate(users: rules.authorship
      .filter({ $0.value.contains(user) })
      .compactMap({ rules.teams[$0.key] })
      .reduce(into: [], { $0.formUnion($1.approvers) })
    )
  }
  public func isCheated(sha: String) -> Bool {
    guard let emergency = rules.emergency.flatMap({ rules.teams[$0] }) else { return false }
    return emergency.isApproved(by: Set(status.approves.filter(\.value.resolution.emergent).keys))
  }
  public func isApproved(sha: String) -> Bool {
    guard status.verification?.value == sha else { return false }
    guard status.approves.filter(\.value.resolution.block).isEmpty else { return false }
    let active = Set(approvers.filter(\.value.active).keys)
    let approvers = Set(status.approves.filter(\.value.resolution.approved).keys)
    let yetActive = active.union(approvers)
    let involved = status.teams
      .compactMap({ rules.teams[$0] })
      .reduce(into: Set(), { $0.formUnion($1.approvers) })
      .intersection(active)
    guard
      status.authors.intersection(yetActive).isEmpty.not,
      status.authors.intersection(active).subtracting(approvers).isEmpty,
      status.randoms.intersection(active).subtracting(approvers).isEmpty,
      status.participants.intersection(involved).subtracting(approvers).isEmpty
    else { return false }
    for team in status.teams {
      guard let team = rules.teams[team], team.isApproved(by: approvers) else { return false }
    }
    return true
  }
  public mutating func squashApproves(sha: Git.Sha) {
    for user in status.approves.keys { status.approves[user]?.commit = sha }
    status.verification = sha
  }
  public mutating func resolveApproval() -> Approval {
    var result = Approval(teams: status.teams)
    var teams = status.teams.reduce(into: [:], { $0[$1] = rules.teams[$1] })
    let active = Set(approvers.filter(\.value.active).keys)
    let outstanders = teams.reduce(into: Set(), { $0.formUnion($1.value.approvers) })
    let approved = Set(status.approves.filter(\.value.resolution.approved).keys)
    let yetActive = active.union(approved)
    teams = teams.reduce(into: teams, { $0[$1.key]?.update(active: yetActive) })
    status.participants = status.participants
      .intersection(teams.reduce(into: [], { $0.formUnion($1.value.approvers) }))
    result.addLabels.formUnion(teams.values.reduce(into: Set(), { $0.formUnion($1.labels) }))
    result.delLabels = rules.teams.values
      .reduce(into: Set(), { $0.formUnion($1.labels) })
      .subtracting(result.addLabels)
    result.mentions.formUnion(teams.values.reduce(into: Set(), { $0.formUnion($1.mentions) }))
    let required = teams.values
      .reduce(into: Set(), { $0.formUnion($1.required) })
      .subtracting(status.authors)
    teams = teams.reduce(into: teams, { $0[$1.key]?.update(involved: required) })
    if kind.proposition {
      let haters = Set(haters.filter({ $0.value.intersection(status.authors).isEmpty.not }).keys)
      let exclude = status.authors.union(haters)
      teams = teams.reduce(into: teams, { $0[$1.key]?.update(exclude: exclude) })
      if status.randoms.count < rules.randoms.quorum {
        let randoms = outstanders
          .subtracting(exclude)
          .intersection(active)
        status.randoms = (0 ..< rules.randoms.quorum - status.randoms.count)
          .reduce(into: Set(), { (acc, _) in
            acc.formUnion(random(users: randoms.subtracting(acc)).array)
          })
      }
    } else {
      teams = teams.reduce(into: teams, { $0[$1.key]?.update(involved: status.authors) })
    }
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
      .union(required)
      .union(necessary)
      .union(optionalRandom)
      .union(reserveRandom)
    result.watchers = optional.subtracting(status.participants)
    result.blockers = status.authors
      .subtracting(approved)
      .union(status.approves.filter(\.value.resolution.block).keys)
    result.slackers = status.participants.union(status.randoms)
    result.approvers = status.participants.intersection(approved)
    result.outdaters = status.participants
      .union(status.randoms)
      .filter({ status.approves[$0].map(\.resolution).get(.outdated) == .outdated })
      .compactMap({ try? [?!status.approves[$0]?.commit.value: Set([$0])] })
      .reduce(into: [:], { $0.merge($1, uniquingKeysWith: { $0.union($1) }) })
    result.update(authors: status.authors)
    if let emergency = rules.emergency.flatMap({ rules.teams[$0] }) {
      result.cheaters = emergency.approvers
        .intersection(status.approves.filter(\.value.resolution.emergent).keys)
      if result.cheaters.count >= emergency.quorum { result.state = .emergent }
    }
    return result
  }
  func getUser(job: Json.GitlabJob) throws -> String {
    let user = job.user.username
    guard let approver = approvers[user] else { throw Thrown("Unknown user: \(user)") }
    guard approver.active else { throw Thrown("Inactive approver: \(user)") }
    return user
  }
  func chechTroubles() -> Troubles? {
    var result = Troubles()
    let requireds = status.teams
      .compactMap({ rules.teams[$0] })
      .reduce(into: Set(), { $0.formUnion($1.required) })
    let excluded = haters
      .filter({ $0.value.intersection(status.authors).isEmpty.not })
      .reduce(into: Set(), { $0.insert($1.key) })
      .subtracting(requireds)
      .subtracting(status.authors)
    let activeApprovers = Set(approvers.filter(\.value.active).keys)
      .union(approvers.filter(\.value.active).keys)
      .subtracting(excluded)
    result.inactiveAuthors = status.authors
      .intersection(activeApprovers)
      .isEmpty
      .then(status.authors)
      .get([])
    result.unapprovalbeTeams = rules.teams
      .filter({ $0.value.approvers.intersection(activeApprovers).count < $0.value.quorum })
      .reduce(into: [], { $0.insert($1.key) })
    result.unknownUsers = status.authors
      .union(status.approves.keys)
      .union(haters.keys)
      .union(haters.flatMap(\.value))
      .union(rules.authorship.flatMap(\.value))
      .union(rules.teams.flatMap(\.value.approvers))
      .subtracting(approvers.keys)
    result.unknownTeams = Set(rules.emergency.array + rules.sanity.array)
      .union(ownage.keys)
      .union(rules.targetBranch.keys)
      .union(rules.sourceBranch.keys)
      .union(rules.authorship.keys)
      .filter { rules.teams[$0] == nil }
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
  public struct Troubles {
    public var inactiveAuthors: Set<String> = []
    public var unapprovalbeTeams: Set<String> = []
    public var unknownUsers: Set<String> = []
    public var unknownTeams: Set<String> = []
    public var isEmpty: Bool {
      inactiveAuthors.isEmpty
      && unapprovalbeTeams.isEmpty
      && unknownUsers.isEmpty
      && unknownTeams.isEmpty
    }
  }
  public struct Approval: Equatable {
    public var teams: Set<String> = []
    public var addLabels: Set<String> = []
    public var delLabels: Set<String> = []
    public var mentions: Set<String> = []
    public var watchers: Set<String> = []
    public var blockers: Set<String> = []
    public var slackers: Set<String> = []
    public var approvers: Set<String> = []
    public var cheaters: Set<String> = []
    public var outdaters: [String: Set<String>] = [:]
    public var state: State = .approved
    mutating func update(authors: Set<String>) {
      if slackers.isEmpty.not { state = .waitingSlackers }
      else if outdaters.isEmpty.not { state = .waitingOutdaters }
      else if blockers.isEmpty { state = .approved }
      else if blockers.subtracting(authors).isEmpty { state = .waitingAuthors }
      else { state = .waitingHolders }
    }
    public enum State: String, Codable {
      case emergent
      case approved
      case waitingAuthors
      case waitingHolders
      case waitingOutdaters
      case waitingSlackers
      public var isApproved: Bool {
        switch self {
        case .emergent, .approved: return true
        default: return false
        }
      }
    }
  }
}
