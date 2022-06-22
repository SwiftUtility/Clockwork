import Foundation
import Facility
public struct AwardApproval {
  public var userActivity: Asset
  public var holdAward: String
  public var sanityGroup: String
  public var allGroups: [String: Group]
  public var emergencyGroup: String?
  public var sourceBranch: [String: Criteria]
  public var targetBranch: [String: Criteria]
  public var personal: [String: Set<String>]
  public var state: State
  public static func make(yaml: Yaml.Controls.AwardApproval) throws -> Self { try Self.init(
    userActivity: .make(yaml: yaml.userActivity),
    holdAward: yaml.holdAward,
    sanityGroup: yaml.sanity,
    allGroups: yaml.groups
      .mapValues(Group.init(yaml:)),
    emergencyGroup: yaml.emergency,
    sourceBranch: yaml.sourceBranch
      .or([:])
      .mapValues(Criteria.init(yaml:)),
    targetBranch: yaml.targetBranch
      .or([:])
      .mapValues(Criteria.init(yaml:)),
    personal: yaml.personal
      .or([:])
      .mapValues(Set.init(_:)),
    state: .init()
  )}
  public mutating func consider(activeUsers: [String: Bool]) {
    state.activeUsers = Set(activeUsers.filter(\.value).keys)
    state.inactiveUsers = Set(activeUsers.keys).subtracting(state.activeUsers)
  }
  public mutating func consider(gitlab: GitlabCi) {
    state.bots.insert(gitlab.botLogin)
  }
  public mutating func consider(review: Json.GitlabReviewState) {
    for (group, criteria) in targetBranch {
      guard !state.involved.contains(group) else { continue }
      if criteria.isMet(review.targetBranch) { state.involved.insert(group) }
    }
    for (group, users) in personal {
      guard !state.involved.contains(group) else { continue }
      if users.contains(review.author.username) { state.involved.insert(group) }
    }
    state.author.insert(review.author.username)
    state.labels = .init(review.labels)
  }
  public mutating func consider(participants: [String]) throws {
    state.participants.formUnion(participants)
  }
  public mutating func consider(
    sanityFiles: [String],
    fileApproval: [String: Criteria],
    changedFiles: [String]
  ) throws {
    let sanityCriteria = try fileApproval[sanityGroup]
      .or { throw Thrown("No sanity ownage") }
    for file in sanityFiles where !sanityCriteria.isMet(file) {
      throw Thrown("\(file) not in \(sanityGroup)")
    }
    for file in changedFiles {
      for (group, criteria) in fileApproval {
        guard !state.involved.contains(group) else { continue }
        if criteria.isMet(file) { state.involved.insert(group) }
      }
    }
  }
  public mutating func consider(awards: [Json.GitlabAward]) throws {
    for award in awards {
      state.awarders[award.name] = state.awarders[award.name].or([]).union([award.user.username])
    }
    for group in state.involved.union([holdAward]) {
      if state.awarders[group].or([]).intersection(state.bots).isEmpty {
        state.unhighlighted.insert(group)
      }
      state.awarders[group] = state.awarders[group]?.subtracting(state.bots)
    }
    state.holders = state.awarders[holdAward]
      .or([])
      .intersection(state.activeUsers)
    if let emergency = emergencyGroup {
      state.isEmergent = try Id(emergency)
        .map(getGroup(name:))
        .map(isApproved(group:))
        .get()
      if state.isEmergent { state.involved.insert(emergency) }
    }
    for group in state.involved where !state.labels.contains(group) {
      state.unnotified.insert(group)
    }
    state.outstanders = state.bots.union(state.author).union(state.inactiveUsers)
  }
  public func makeNewApprovals(
    cfg: Configuration,
    review: Json.GitlabReviewState
  ) throws -> [Report]? {
    guard !state.unnotified.isEmpty else { return nil }
    var newGroups: [Group.New] = []
    for name in state.unnotified {
      let group = try getGroup(name: name)
      let required = group.required.subtracting(state.outstanders)
      var optional = group.optional.subtracting(state.outstanders)
      let reserved = group.reserved.subtracting(state.outstanders)
      if required.union(optional).count < group.quorum { optional = optional.union(reserved) }
      newGroups.append(.init(
        name: name,
        award: group.award,
        required: required.isEmpty
          .else(.init(required)),
        optional: (required.count < group.quorum)
          .then(.init(optional)),
        optionals: group.quorum - required.count
      ))
    }
    return [cfg.reportNewAwardApprovals(
      review: review,
      users: state.participants,
      groups: newGroups
    )] + newGroups.map { group in cfg.reportNewAwardApprovalGroup(
      review: review,
      users: state.participants,
      group: group
    )}
  }
  public func makeUnapprovedGroups() throws -> Set<String>? {
    guard !state.isEmergent else { return nil }
    let unapproved = try state.involved
      .filter { try !isApproved(group: getGroup(name: $0)) }
    return unapproved.isEmpty.else(unapproved)
  }
  public func makeHoldersReport(
    cfg: Configuration,
    review: Json.GitlabReviewState
  ) throws -> Report? {
    var holders = state.holders.subtracting(state.inactiveUsers)
    if state.isEmergent { holders = try emergencyGroup
      .map(getGroup(name:))
      .map { $0.required.union($0.reserved) }
      .or { throw MayDay("No emergency group") }
      .intersection(holders)
    }
    guard holders.isEmpty else { return nil }
    return cfg.reportAwardApprovalHolders(
      review: review,
      users: state.participants,
      holders: holders
    )
  }
  public func getGroup(name: String) throws -> Group {
    try allGroups[name].or { throw Thrown("approval.groups: no \(name)") }
  }
  public func isApproved(group: Group) -> Bool {
    let awarders = state.awarders[group.award].or([])
    var invloved = group.required
      .subtracting(state.outstanders)
    guard invloved.isSubset(of: awarders) else { return false }
    guard invloved.count < group.quorum else { return true }
    invloved = group.optional
      .subtracting(state.outstanders)
      .intersection(awarders)
      .union(invloved)
    guard invloved.count < group.quorum else { return true }
    invloved = group.reserved
      .subtracting(state.outstanders)
      .intersection(awarders)
      .union(invloved)
    return invloved.count >= group.quorum
  }
  public struct State {
    public var bots: Set<String> = []
    public var author: Set<String> = []
    public var participants: Set<String> = []
    public var inactiveUsers: Set<String> = []
    public var activeUsers: Set<String> = []
    public var fileApproval: [String: Criteria] = [:]
    public var labels: Set<String> = []
    public var awarders: [String: Set<String>] = [:]
    public var involved: Set<String> = []
    public var unhighlighted: Set<String> = []
    public var unnotified: Set<String> = []
    public var holders: Set<String> = []
    public var outstanders: Set<String> = []
    public var isEmergent = false
  }
  public struct Group {
    public var award: String
    public var quorum: Int
    public var required: Set<String>
    public var optional: Set<String>
    public var reserved: Set<String>
    public init(yaml: Yaml.Controls.AwardApproval.Group) {
      self.award = yaml.award
      self.quorum = yaml.quorum
      self.reserved = .init(yaml.reserve.or([]))
      self.optional = .init(yaml.optional.or([]))
      self.required = .init(yaml.required.or([]))
    }
    public struct New: Encodable {
      public var name: String
      public var award: String
      public var required: [String]?
      public var optional: [String]?
      public var optionals: Int
    }
  }
  public enum Mode {
    case resolution
    case replication
    case integration
  }
}
