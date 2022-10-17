import Foundation
import Facility
public struct Review {
  public let bot: String
  public let approvers: [String: Fusion.Approval.Approver]
  public let kind: Fusion.Kind
  public let ownage: [String: Criteria]
  public let rules: Fusion.Approval.Rules
  public let haters: [String: Set<String>]
  public let unknownUsers: Set<String>
  public let unknownTeams: Set<String>
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
  ) -> Self { .init(
    bot: bot,
    approvers: approvers,
    kind: kind,
    ownage: ownage,
    rules: rules,
    haters: haters,
    unknownUsers: status.authors
      .union(status.approves.keys)
      .union(haters.keys)
      .union(haters.flatMap(\.value))
      .union(rules.authorship.flatMap(\.value))
      .union(rules.teams.flatMap(\.value.approvers))
      .subtracting(approvers.keys),
    unknownTeams: Set(rules.sanity.array)
      .union(ownage.keys)
      .union(rules.targetBranch.keys)
      .union(rules.sourceBranch.keys)
      .union(rules.authorship.keys)
      .filter { rules.teams[$0] == nil },
    status: status
  )}
  public func isApproved(sha: String) -> Bool {
    guard status.verification?.value == sha else { return false }
    guard status.emergent.not else { return true }
    let active = Set(approvers.filter(\.value.active).keys)
    let blockers = Set(status.approves.filter(\.value.resolution.block).keys)
    guard blockers.intersection(active).isEmpty else { return false }
    return status.participants
      .union(status.randoms)
      .union(status.authors)
      .intersection(active)
      .subtracting(status.approves.filter(\.value.resolution.approved).keys)
      .isEmpty
  }
  public mutating func approve(
    job: Json.GitlabJob,
    resolution: Yaml.Fusion.Approval.Status.Resolution
  ) throws {
    let user = try getUser(job: job)
    status.approves[user] = try .init(
      approver: user,
      commit: .make(job: job),
      resolution: resolution
    )
  }
  public mutating func setAuthor(job: Json.GitlabJob) throws {
    let user = try getUser(job: job)
    status.authors.insert(user)
    guard kind.proposition else { return }
    status.invalidate(users: rules.authorship
      .filter({ $0.value.contains(user) })
      .compactMap({ rules.teams[$0.key] })
      .reduce(into: [user], { $0.formUnion($1.approvers) })
    )
  }
  public mutating func prepareVerification(source: String, target: String) {
    let authorshipTeams = kind.proposition
      .then(rules.authorship)
      .get([:])
      .filter({ $0.value.intersection(status.authors).isEmpty.not })
      .reduce(into: Set(), { $0.insert($1.key) })
    let sourceTeams = rules.sourceBranch.filter({ $0.value.isMet(source) }).keys
    let targetTeams = rules.targetBranch.filter({ $0.value.isMet(target) }).keys
    utilityTeams = authorshipTeams
      .union(sourceTeams)
      .union(targetTeams)
    if status.target != target {
      status.invalidate(users: Set(targetTeams
        .flatMap({ rules.teams[$0].map(\.approvers).get([]) })
      ))
      status.target = target
    }
    if utilityTeams.subtracting(status.teams).isEmpty.not {
      status.verification = nil
    }
  }
  public mutating func prepareVerification(diff: [String]) {
    diffTeams = Set(ownage.filter({ diff.contains(where: $0.value.isMet(_:)) }).keys)
    status.teams = diffTeams.union(utilityTeams)
  }
  public mutating func addBreakers(sha: Git.Sha, commits: [Git.Sha]) {
    childCommits[sha] = Set(commits)
  }
  public mutating func addChanges(sha: Git.Sha, diff: [String]) {
    guard diff.isEmpty.not else { return }
    changedTeams[sha] = diffTeams.filter({ ownage[$0]
      .map({ diff.contains(where: $0.isMet(_:)) })
      .get(false)
    })
  }
  public mutating func squashApproves(sha: Git.Sha) {
    for user in status.approves.keys { status.approves[user]?.commit = sha }
    status.verification = sha
  }
  public mutating func performVerification(sha: Git.Sha) -> Approval {
    guard status.emergent.not else {
      status.verification = sha
      return Approval(emergent: true)
    }
    let fragilUsers = rules.teams.keys
      .filter(utilityTeams.contains(_:))
      .compactMap({ rules.teams[$0] })
      .filter(\.advanceApproval.not)
      .reduce(into: Set(), { $0.formUnion($1.approvers) })
      .union(status.authors)
      .union(status.approves.filter(\.value.resolution.fragil).keys)
    let diffApprovers = diffTeams.reduce(into: [:], { $0[$1] = rules.teams[$1]?.approvers })
    for (sha, childs) in childCommits {
      let breakers = childs.compactMap({ changedTeams[$0] })
      guard breakers.isEmpty.not else { continue }
      let approvers = status.approves.values
        .filter({ $0.commit == sha && $0.resolution.approved })
        .map(\.approver)
      status.invalidate(users: breakers
        .reduce(into: Set(), { $0.formUnion($1) })
        .compactMap({ diffApprovers[$0] })
        .reduce(into: fragilUsers, { $0.formUnion($1) })
        .intersection(approvers)
      )
    }
    var result = Approval()
    var teams = status.teams.reduce(into: [:], { $0[$1] = rules.teams[$1] })
    result.watchers = teams.values.reduce(into: Set(), { $0.formUnion($1.optional) })
    result.addLabels.formUnion(teams.values.reduce(into: Set(), { $0.formUnion($1.labels) }))
    result.delLabels = teams.values
      .reduce(into: Set(), { $0.formUnion($1.labels) })
      .subtracting(result.addLabels)
    result.mentions = teams.values.reduce(into: Set(), { $0.formUnion($1.mentions) })
    let active = Set(approvers.filter(\.value.active).keys)
    let approved = Set(status.approves.filter(\.value.resolution.approved).keys)
    let yetActive = active.union(approved)
    let involved = teams.reduce(into: Set(), { $0.formUnion($1.value.approvers) })
    result.inactiveAuthors = status.authors.intersection(yetActive).isEmpty
    teams.keys.forEach({ teams[$0]?.update(active: yetActive) })
    if kind.proposition {
      teams.keys.forEach({ teams[$0]?.update(exclude: status.authors) })
    } else {
      teams.keys.forEach({ teams[$0]?.update(involved: status.authors) })
    }
    result.unapprovableTeams = teams.values
      .filter({ $0.approvers.count < $0.quorum })
      .reduce(into: [], { $0.insert($1.name) })
    guard result.isUnapprovable.not else { return result }
    status.verification = sha
    status.participants = status.participants
      .intersection(yetActive)
      .intersection(involved)
      .subtracting(status.authors)
    status.randoms = status.randoms
      .subtracting(status.authors)
    teams.keys.forEach({ teams[$0]?.update(involved: status.randoms) })
    teams.keys.forEach({ teams[$0]?.update(involved: status.participants) })
    let required = teams.values
      .reduce(into: Set(), { $0.formUnion($1.required) })
    status.participants.formUnion(required)
    teams.keys.forEach({ teams[$0]?.update(involved: required) })
    if kind.proposition, status.randoms.count < rules.randoms.quorum {
      let outstanders = active
        .subtracting(involved)
        .subtracting(haters.filter({ $0.value.intersection(status.authors).isEmpty.not }).keys)
        .subtracting(status.authors)
      status.randoms = (0 ..< rules.randoms.quorum - status.randoms.count)
        .reduce(into: status.randoms, { (acc, _) in
          acc.formUnion(random(users: outstanders.subtracting(acc)).array)
        })
    }
    let optional = teams.values.reduce(into: Set(), { $0.formUnion($1.optional) })
    teams.keys.forEach({ teams[$0]?.update(optional: optional) })
    let necessary = teams.values.reduce(into: Set(), { $0.formUnion($1.necessary) })
    status.participants.formUnion(necessary)
    teams.keys.forEach({ teams[$0]?.update(involved: necessary) })
    let reserveTeams = teams.filter({ $0.value.optional.isEmpty && $0.value.quorum > 0 })
    let reserveRandom = selectUsers(
      teams: reserveTeams,
      users: reserveTeams.values.reduce(into: Set(), { $0.formUnion($1.reserve) })
    )
    status.participants.formUnion(reserveRandom)
    teams.keys.forEach({ teams[$0]?.update(involved: reserveRandom) })
    let optionalTeams = teams.filter({ $0.value.optional.isEmpty.not && $0.value.quorum > 0 })
    let optionalRandom = selectUsers(
      teams: optionalTeams,
      users: optionalTeams.values.reduce(into: Set(), { $0.formUnion($1.optional) })
    )
    status.participants.formUnion(optionalRandom)
    teams.keys.forEach({ teams[$0]?.update(involved: optionalRandom) })
    result.authors = status.authors
      .intersection(yetActive)
    result.watchers = result.watchers
      .intersection(active)
      .subtracting(status.participants)
      .subtracting(status.randoms)
      .subtracting(status.authors)
    result.blockers = status.authors
      .subtracting(approved)
      .union(status.approves.filter(\.value.resolution.block).keys)
    result.slackers = status.participants
      .union(status.randoms)
      .subtracting(status.approves.keys)
    result.approvers = status.participants
      .union(status.randoms)
      .intersection(approved)
    result.outdaters = status.participants
      .union(status.randoms)
      .compactMap({ status.approves[$0] })
      .filter(\.resolution.outdated)
      .map({ [$0.commit.value: Set([$0.approver])] })
      .reduce(into: [:], { $0.merge($1, uniquingKeysWith: { $0.union($1) }) })
    return result
  }
  func getUser(job: Json.GitlabJob) throws -> String {
    let user = job.user.username
    guard let approver = approvers[user] else { throw Thrown("Unknown user: \(user)") }
    guard approver.active else { throw Thrown("Inactive approver: \(user)") }
    return user
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
  public struct Approval: Equatable {
    public var emergent: Bool = false
    public var teams: Set<String> = []
    public var addLabels: Set<String> = []
    public var delLabels: Set<String> = []
    public var mentions: Set<String> = []
    public var watchers: Set<String> = []
    public var blockers: Set<String> = []
    public var slackers: Set<String> = []
    public var approvers: Set<String> = []
    public var authors: Set<String> = []
    public var outdaters: [String: Set<String>] = [:]
    public var inactiveAuthors: Bool = false
    public var unapprovableTeams: Set<String> = []
    public var isUnapprovable: Bool {
      inactiveAuthors || unapprovableTeams.isEmpty.not
    }
    public var state: State {
      if emergent { return .emergent }
      else if slackers.isEmpty.not { return .waitingSlackers }
      else if outdaters.isEmpty.not { return .waitingOutdaters }
      else if blockers.isEmpty { return .approved }
      else if blockers.subtracting(authors).isEmpty { return .waitingAuthors }
      else { return .waitingHolders }
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
  public struct Context {
    public let gitlab: GitlabCi
    public let job: Json.GitlabJob
    public let profile: Files.Relative
    public let review: Json.GitlabReviewState
    public let isLastPipe: Bool
    public var isActual: Bool { return isLastPipe && review.state == "opened" }
    public static func make(
      gitlab: GitlabCi,
      job: Json.GitlabJob,
      profile: Files.Relative,
      review: Json.GitlabReviewState,
      isLastPipe: Bool
    ) -> Self { .init(
      gitlab: gitlab,
      job: job,
      profile: profile,
      review: review,
      isLastPipe: isLastPipe
    )}
  }
}
