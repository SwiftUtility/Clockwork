import Foundation
import Facility
public struct Review {
  public let bot: String
  public let statuses: [UInt: Fusion.Approval.Status]
  public let state: Json.GitlabReviewState
  public let approvers: [String: Fusion.Approval.Approver]
  public let kind: Fusion.Kind
  public let ownage: [String: Criteria]
  public let rules: Fusion.Approval.Rules
  public let haters: [String: Set<String>]
  public let utilityTeams: Set<String>
  public private(set) var changedTeams: [Git.Sha: Set<String>] = [:]
  public private(set) var status: Fusion.Approval.Status
  public private(set) var diffTeams: Set<String> = []
  public private(set) var childCommits: [Git.Sha: Set<Git.Sha>] = [:]
  public init(
    gitlabCi: GitlabCi,
    statuses: [UInt: Fusion.Approval.Status],
    approvers: [String: Fusion.Approval.Approver],
    review: Json.GitlabReviewState,
    kind: Fusion.Kind,
    ownage: [String: Criteria],
    rules: Fusion.Approval.Rules,
    haters: [String: Set<String>]
  ) throws {
    let unknownTeams = Set(rules.emergency.array + rules.sanity.array)
      .union(ownage.keys)
      .union(rules.targetBranch.keys)
      .union(rules.sourceBranch.keys)
      .union(rules.authorship.keys)
      .filter { rules.teams[$0] == nil }
      .joined(separator: ", ")
    guard unknownTeams.isEmpty else { throw Thrown("Unknown teams: \(unknownTeams)") }
    let status = try statuses[review.iid].get { throw Thrown("No review status in asset") }
    self.bot = try gitlabCi.protected.get().user.username
    self.state = review
    self.statuses = statuses
    self.approvers = approvers
    self.status = status
    self.kind = kind
    self.ownage = ownage
    self.rules = rules
    self.haters = haters
    self.utilityTeams = (kind.merge == nil).then(rules.authorship).get([:])
      .filter({ !$0.value.intersection(status.authors).isEmpty })
      .reduce(into: Set(), { $0.insert($1.key) })
      .union(rules.sourceBranch.filter({ $0.value.isMet(review.sourceBranch) }).keys)
      .union(rules.targetBranch.filter({ $0.value.isMet(review.targetBranch) }).keys)
    if status.target != review.targetBranch {
      self.status.invalidate(users: rules.targetBranch
        .filter { $0.value.isMet(status.target) }
        .compactMap { rules.teams[$0.key] }
        .reduce(Set()) { $0.union($1.approvers) }
      )
    }
    self.status.target = review.targetBranch
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
    guard kind.merge == nil else { return }
    status.invalidate(users: rules.authorship
      .filter({ $0.value.contains(user) })
      .compactMap({ rules.teams[$0.key] })
      .reduce(into: [], { $0.formUnion($1.approvers) })
    )
  }
  public mutating func updateApproval() -> Approval {
    var approval = Approval(statuses: statuses)
    let approves = resolveApproves()
    updateParticipants(approves: approves)
    approval.troubles = resolveTroubles()
    #warning("calc update")
    approval.statuses[state.iid] = status
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
    var teams = diffTeams.union(utilityTeams).compactMap({ rules.teams[$0] })
    let required = teams.reduce(into: Set(), { $0.formUnion($1.required) })
    let antagonitsts = status.makeAntagonitsts(kind: kind, haters: haters)
    let inactive = Set(approvers.filter(\.value.active.not).keys)
    let yetActive = inactive.intersection(approves.filter(\.value.approved).keys)

//    let activeApprovers = Set(approvers.filter(\.value.active).keys)
//    let antagonists = status.makeAntagonitsts(kind: kind, haters: haters)
//    let inactive = antagonists
//      .subtracting(required)
//      .union(status.authors)
//      .union(<#T##other: Sequence##Sequence#>)
//    status.participants = status.participants
//      .union(status.approves.keys)
//      .subtracting(status.randoms)
//      .subtracting(inactive)
//      .union(required)
//    involved = involved.
//      .union(status.participants)
//      .union(status.approves.map(\.key))
//    involved.subtracting(inactive)

//    let requiredUsers = diffTeams
//      .union(utilityTeams)
//      .compactMap({ rules.teams[$0] })
//      .reduce(Set(), { $0.union($1.required) })
//    status.participants = status.participants
//      .union(status.approves.map(\.key))
//      .subtracting(antagonists)

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
//  func randoms(teams: Set<String>) -> Set<String> {
//    let randoms = rules.randoms
//    guard case .proposition = kind else { return [] }
//    var all = Set(approvers.keys)
//    let excluded = all
//      .subtracting(activeApprovers)
//      .union(antagonistApprovers)
//      .subtracting(status.authors)
//    var involved: Set<String> = []
//    var count: Int = 0
//    let teams = teams.compactMap({ rules.teams[$0] })
//    for team in teams {
//      count += team.required
//        .subtracting(excluded)
//        .subtracting(involved)
//        .count
//      involved.formUnion(team.required)
//    }
//    for team in teams {
//      count += max(0, team.quorum - team.approvers
//        .subtracting(excluded)
//        .subtracting(involved)
//      )
//      let ss = team.approvers
//      let miss = max(0, team.quorum - team.required
//        .subtracting(inactive)
//        .subtracting(status.authors)
//        .count
//      )
//      let approvers = team.approvers.subtracting(excluded)
//      count += min(miss, approvers.count)
//      excluded.formUnion(approvers)
//    }
//    count = max(0, randoms.quorum - count)
//    all = all.subtracting(excluded).filter({ randoms.weights[$0].get(randoms.baseWeight) > 0 })
//    guard all.count > count else { return all }
//    var result: Set<String> = []
//    for _ in 0..<count {
//      let users = all.subtracting(result).sorted()
//      var acc = users.map({ randoms.weights[$0].get(randoms.baseWeight) }).reduce(0, +)
//      acc = Int.random(in: 0 ..< acc)
//      let user = users.first(where: {
//        acc -= randoms.weights[$0].get(randoms.baseWeight)
//        return acc < 0
//      })
//      result.formUnion(user.array)
//    }
//    return result
//  }
//  func approves() -> [String: Fusion.Approval.Status.Review.Approve] {
//    guard let merge = kind.merge else { return [:] }
//    let approve = Fusion.Approval.Status.Review.Approve(commit: merge.fork, resolution: .fragil)
//    return status.authors.reduce(into: [:]) { $0[$1] = approve }
//  }
  public struct Approval {
    public var update: Update = .init()
    public var statuses: [UInt: Fusion.Approval.Status] = [:]
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
//public struct AwardApproval {
//  public var holdAward: String
//  public var sanityGroup: String
//  public var allGroups: [String: Group]
//  public var emergencyGroup: String?
//  public var sourceBranch: [String: Criteria]
//  public var targetBranch: [String: Criteria]
//  public var personal: [String: Set<String>]
//  public var statusLabel: String
//  public static func make(yaml: Yaml.AwardApproval) throws -> Self { try Self.init(
//    holdAward: yaml.holdAward,
//    sanityGroup: yaml.sanity,
//    allGroups: yaml.groups
//      .map(Group.make(name:yaml:))
//      .reduce(into: [:]) { $0[$1.name] = $1 },
//    emergencyGroup: yaml.emergency,
//    sourceBranch: yaml.sourceBranch
//      .get([:])
//      .mapValues(Criteria.init(yaml:)),
//    targetBranch: yaml.targetBranch
//      .get([:])
//      .mapValues(Criteria.init(yaml:)),
//    personal: yaml.personal
//      .get([:])
//      .mapValues(Set.init(_:)),
//    statusLabel: yaml.statusLabel
//  )}
//  public func get(group: String) throws -> Group {
//    try allGroups[group].get { throw Thrown("Group \(group) not configured") }
//  }
//  public struct Users {
//    public var bot: String
//    public var author: String
//    public var voiceless: Set<String>
//    public var holdables: Set<String>
//    public var coauthors: Set<String>
//    public var awarders: [String: Set<String>]
//    public init(
//      bot: String,
//      author: String,
//      participants: [String],
//      approval: AwardApproval,
//      awards: [Json.GitlabAward],
//      userActivity: [String: Bool]
//    ) throws {
//      self.bot = bot
//      self.author = author
//      self.coauthors = Set(participants).union([author])
//      let known = Set(userActivity.keys).union([bot])
//      self.voiceless = Set(userActivity.filter(\.value.not).keys).union([author, bot])
//      self.holdables = known
//        .subtracting(voiceless)
//        .union([author])
//        .subtracting([bot])
//      self.awarders = awards.reduce(into: [:]) { awarders, award in
//        awarders[award.name] = awarders[award.name].get([]).union([award.user.username])
//      }
//      let unknown = approval.allGroups.values
//        .reduce(into: coauthors) { unknown, group in
//          unknown.formUnion(group.required)
//          unknown.formUnion(group.optional)
//          unknown.formUnion(group.reserved)
//        }
//        .subtracting(known)
//        .joined(separator: ", ")
//      guard unknown.isEmpty else { throw Thrown("Not configured users: \(unknown)") }
//    }
//  }
//  public struct Groups {
//    public var emergency: Bool
//    public var cheaters: Set<String>
//    public var unhighlighted: Set<String> = []
//    public var unreported: [Group.Report] = []
//    public var unapproved: [Group.Report] = []
//    public var neededLabels: String
//    public var extraLabels: String
//    public var reportSuccess: Bool
//    public var holders: Set<String>
//    public init(
//      sourceBranch: String,
//      targetBranch: String,
//      labels: [String],
//      users: Users,
//      approval: AwardApproval,
//      sanityFiles: [String],
//      fileApproval: [String: Criteria],
//      changedFiles: [String]
//    ) throws {
//      let sanity = try fileApproval[approval.sanityGroup]
//        .get { throw Thrown("\(approval.sanityGroup) ownage not configured locally") }
//      try sanityFiles
//        .filter { !sanity.isMet($0) }
//        .forEach { throw Thrown("\($0) not in \(approval.sanityGroup)") }
//      let reported = Set(labels)
//      var involved: Set<String> = []
//      for (group, authors) in approval.personal
//      where !involved.contains(group) && authors.contains(users.author)
//      { involved.insert(group) }
//      for (group, criteria) in approval.targetBranch
//      where !involved.contains(group) && criteria.isMet(targetBranch)
//      { involved.insert(group) }
//      for (group, criteria) in approval.sourceBranch
//      where !involved.contains(group) && criteria.isMet(sourceBranch)
//      { involved.insert(group) }
//      for (group, criteria) in fileApproval
//      where !involved.contains(group) && changedFiles.contains(where: criteria.isMet(_:))
//      { involved.insert(group) }
//      if !users.awarders[approval.holdAward].get([]).contains(users.bot)
//      { unhighlighted.insert(approval.holdAward) }
//      for group in try involved.map(approval.get(group:)) {
//        if !users.awarders[group.award].get([]).contains(users.bot)
//        { unhighlighted.insert(group.award) }
//        if !reported.contains(group.name)
//        { unreported.append(.makeUnreported(group: group, users: users)) }
//        if try !group.isApproved(users: users)
//        { unapproved.append(.makeUnapproved(group: group, users: users)) }
//      }
//      if
//        let emergency = try approval.emergencyGroup.map(approval.get(group:)),
//        try emergency.isApproved(users: users)
//      {
//        let approvers = emergency.required
//          .union(emergency.optional)
//          .union(emergency.reserved)
//        self.emergency = true
//        if reported.contains(emergency.name) {
//          self.cheaters = []
//        } else {
//          self.cheaters = users.awarders[emergency.award]
//            .get([])
//            .intersection(approvers)
//            .subtracting(users.voiceless)
//        }
//        self.holders = users.awarders[approval.holdAward]
//          .get([])
//          .intersection(approvers)
//          .intersection(users.holdables)
//        involved.insert(emergency.name)
//      } else {
//        self.emergency = false
//        self.cheaters = []
//        self.holders = users.awarders[approval.holdAward]
//          .get([])
//          .intersection(users.holdables)
//      }
//      let isApproved = holders.isEmpty && (emergency || unapproved.isEmpty)
//      self.neededLabels = involved
//        .union(isApproved.then(approval.statusLabel).array)
//        .subtracting(reported)
//        .joined(separator: ",")
//      self.extraLabels = Set(approval.allGroups.keys)
//        .subtracting(involved)
//        .union(isApproved.else(approval.statusLabel).array)
//        .intersection(reported)
//        .joined(separator: ",")
//      self.reportSuccess = isApproved
//      && !reported.contains(approval.statusLabel)
//      && !involved.isEmpty
//    }
//  }
//  public struct Group {
//    public var name: String
//    public var award: String
//    public var quorum: Int
//    public var required: Set<String>
//    public var optional: Set<String>
//    public var reserved: Set<String>
//    public static func make(
//      name: String,
//      yaml: Yaml.AwardApproval.Group
//    ) throws -> Self { try .init(
//      name: name,
//      award: yaml.award,
//      quorum: (yaml.quorum > 0)
//        .then(yaml.quorum)
//        .get { throw Thrown("Zero quorum group: \(name)") },
//      required: .init(yaml.required.get([])),
//      optional: .init(yaml.optional.get([])),
//      reserved: .init(yaml.reserve.get([]))
//    )}
//    public func isApproved(users: Users) throws -> Bool {
//      guard quorum <= required.union(optional).union(reserved).subtracting(users.voiceless).count
//      else { throw Thrown("Unapprovable group: \(name)") }
//      let awarders = users.awarders[award].get([])
//      let required = required
//        .subtracting(users.voiceless)
//      guard awarders.isSuperset(of: required) else { return false }
//      var quote = quorum - required.count
//      guard quote > 0 else { return true }
//      let optional = optional
//        .subtracting(required)
//        .subtracting(users.voiceless)
//      quote -= optional.intersection(awarders).count
//      guard quote > 0 else { return true }
//      let reserved = reserved
//        .subtracting(required)
//        .subtracting(optional)
//        .subtracting(users.voiceless)
//      quote -= reserved.intersection(awarders).count
//      guard quote > 0 else { return true }
//      return false
//    }
//    public struct Report: Encodable {
//      public var name: String
//      public var award: String
//      public var required: [String]?
//      public var optional: [String]?
//      public var optionals: Int
//      public static func makeUnreported(group: Group, users: Users) -> Self {
//        let required = group.required.subtracting(users.voiceless)
//        let optionals = max(0, group.quorum - required.count)
//        var optional = group.optional
//          .subtracting(group.required)
//          .subtracting(users.voiceless)
//        if optional.count < optionals { optional = optional
//          .union(group.reserved)
//          .subtracting(group.required)
//          .subtracting(users.voiceless)
//        }
//        return .init(
//          name: group.name,
//          award: group.award,
//          required: required.isEmpty
//            .else(required)
//            .map(Array.init(_:)),
//          optional: (optionals == 0)
//            .else(optional)
//            .map(Array.init(_:)),
//          optionals: optionals
//        )
//      }
//      public static func makeUnapproved(group: Group, users: Users) -> Self {
//        var required = group.required.subtracting(users.voiceless)
//        var optionals = max(0, group.quorum - required.count)
//        let awarders = users.awarders[group.award].get([])
//        required = required.subtracting(awarders)
//        var optional = group.optional
//          .subtracting(group.required)
//          .subtracting(users.voiceless)
//        if optional.count < optionals { optional = optional
//          .union(group.reserved)
//          .subtracting(group.required)
//          .subtracting(users.voiceless)
//        }
//        optionals = max(0, optionals - optional.intersection(awarders).count)
//        optional = optional.subtracting(awarders)
//        return .init(
//          name: group.name,
//          award: group.award,
//          required: required.isEmpty
//            .else(required)
//            .map(Array.init(_:)),
//          optional: optional.isEmpty
//            .else(optional)
//            .map(Array.init(_:)),
//          optionals: optionals
//        )
//      }
//    }
//  }
//  public enum Mode {
//    case resolution
//    case replication
//    case integration
//  }
//}
