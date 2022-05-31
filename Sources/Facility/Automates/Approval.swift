import Foundation
import Facility
public struct Approval {
  public var holdAward: String
  public var holdUsers: Set<String>
  public var botLogin: String?
  public var groups: [String: Group]
  public var sanity: String?
  public var emergency: String?
  public var targetBranchApproval: [String: Criteria]
  public var personalApproval: [String: Set<String>]
  public var bots: Set<String> = []
  public var author: Set<String> = []
  public var vacationers: Set<String> = []
  public var fileApproval: [String: Criteria]? = nil
  public var labels: Set<String> = []
  public var awarders: [String: Set<String>] = [:]
  public var involved: Set<String> = []
  public var unhighlighted: Set<String> = []
  public var unnotified: Set<String> = []
  public var holders: Set<String> = []
  public var outstanders: Set<String> = []
  public var isEmergent = false
  public var resolver: String?
  public static func make(yaml: Yaml.Approval) throws -> Self { try .init(
    holdAward: yaml.holders.award,
    holdUsers: .init(yaml.holders.users),
    groups: yaml.groups.mapValues(Group.init(yaml:)),
    sanity: yaml.sanity,
    emergency: yaml.emergency,
    targetBranchApproval: yaml.targetBranch
      .or([:])
      .mapValues(Criteria.init(yaml:)),
    personalApproval: yaml.personal
      .or([:])
      .mapValues(Set<String>.init(_:))
  )}
  public mutating func consider(gitlab: Gitlab) {
    botLogin = gitlab.botLogin
    bots.insert(gitlab.botLogin)
  }
  public mutating func consider(state: Json.GitlabReviewState) {
    for (group, criteria) in targetBranchApproval {
      guard !involved.contains(group) else { continue }
      if criteria.isMet(state.targetBranch) { involved.insert(group) }
    }
    for (group, users) in personalApproval {
      guard !involved.contains(group) else { continue }
      if users.contains(state.author.username) { involved.insert(group) }
    }
    author.insert(state.author.username)
    labels = .init(state.labels)
  }
  public mutating func consider(resolver: String?) throws {
    if let resolver = resolver {
      author.insert(resolver)
      self.resolver = resolver
    }
  }
  public mutating func consider(
    sanityFiles: [String],
    fileApproval: [String: Criteria],
    changedFiles: [String]
  ) throws {
    if let sanity = sanity {
      guard let sanityCriteria = fileApproval[sanity] else { throw Thrown("No sanity approvers") }
      for file in sanityFiles where !sanityCriteria.isMet(file) {
        throw Thrown("\(file) not in \(sanity)")
      }
    }
    for file in changedFiles {
      for (group, criteria) in fileApproval {
        guard !involved.contains(group) else { continue }
        if criteria.isMet(file) { involved.insert(group) }
      }
    }
  }
  public mutating func consider(awards: [Json.GitlabAward], vacationers: Set<String>?) throws {
    for award in awards {
      awarders[award.name] = awarders[award.name].or([]).union([award.user.username])
    }
    self.vacationers = vacationers.or([])
    for group in involved.union([holdAward]) {
      if awarders[group].or([]).intersection(bots).isEmpty { unhighlighted.insert(group) }
      awarders[group] = awarders[group]?.subtracting(bots)
    }
    self.holders = awarders[holdAward]
      .or([])
      .intersection(holdUsers)
    if let emergency = emergency {
      isEmergent = try Id(emergency)
        .map(getGroup(name:))
        .map(isApproved(group:))
        .get()
      if isEmergent { involved.insert(emergency) }
    }
    for group in involved where !labels.contains(group) {
      unnotified.insert(group)
    }
    outstanders = bots.union(author).union(self.vacationers)
  }
  public func makeNewApprovals(
    cfg: Configuration,
    state: Json.GitlabReviewState
  ) throws -> [Report]? {
    guard !unnotified.isEmpty else { return nil }
    var newGroups: [Context] = []
    for name in unnotified {
      let group = try getGroup(name: name)
      let required = group.required.subtracting(outstanders)
      var optional = group.optional.subtracting(outstanders)
      let reserved = group.reserved.subtracting(outstanders)
      if required.union(optional).count < group.quorum { optional = optional.union(reserved) }
      let involved = group.required.union(optional)
      newGroups.append(.init(
        name: name,
        award: group.award,
        required: .init(approval: self, members: required, award: group.award),
        optional: .init(approval: self, members: optional, award: group.award),
        involved: .init(approval: self, members: involved, award: group.award),
        quote: (required.count < group.quorum)
          .then(group.quorum - required.count),
        quorum: group.quorum
      ))
    }
    return [.approvalGroups(.init(
      env: cfg.env,
      review: state,
      custom: cfg.stencil.custom,
      user: resolver.flatMapNil(botLogin),
      groups: newGroups
    ))] + newGroups.map { group in Report.approvalGroup(.init(
      env: cfg.env,
      review: state,
      custom: cfg.stencil.custom,
      user: resolver.flatMapNil(botLogin),
      group: group
    ))}
  }
  public func makeUnapprovedGroups() throws -> Set<String>? {
    guard !isEmergent else { return nil }
    let unapproved = try involved
      .filter { try !isApproved(group: getGroup(name: $0)) }
    return unapproved.isEmpty.else(unapproved)
  }
  public func makeHoldersReport(
    cfg: Configuration,
    state: Json.GitlabReviewState
  ) throws -> Report? {
    var holders = self.holders.subtracting(vacationers)
    if isEmergent { holders = try emergency
      .map(getGroup(name:))
      .map { $0.required.union($0.reserved) }
      .or { throw MayDay("No emergency group") }
      .intersection(holders)
    }
    guard holders.isEmpty else { return nil }
    return .approvalHolders(.init(
      env: cfg.env,
      review: state,
      custom: cfg.stencil.custom,
      user: resolver.flatMapNil(botLogin),
      holders: holders
    ))
  }
  public func getGroup(name: String) throws -> Group {
    try groups[name].or { throw Thrown("approval.groups: no \(name)") }
  }
  public func isApproved(group: Group) -> Bool {
    let awarders = awarders[group.award].or([])
    var invloved = group.required
      .subtracting(outstanders)
    guard invloved.isSubset(of: awarders) else { return false }
    guard invloved.count < group.quorum else { return true }
    invloved = group.optional
      .subtracting(outstanders)
      .intersection(awarders)
      .union(invloved)
    guard invloved.count < group.quorum else { return true }
    invloved = group.reserved
      .subtracting(outstanders)
      .intersection(awarders)
      .union(invloved)
    return invloved.count >= group.quorum
  }
  public struct Group {
    public var award: String
    public var quorum: Int
    public var required: Set<String>
    public var optional: Set<String>
    public var reserved: Set<String>
    public init(yaml: Yaml.Approval.Group) {
      self.award = yaml.award
      self.quorum = yaml.quorum
      self.reserved = .init(yaml.reserve.or([]))
      self.optional = .init(yaml.optional.or([]))
      self.required = .init(yaml.required.or([]))
    }
  }
  public struct Context: Codable {
    public var name: String
    public var award: String
    public var required: Approvers
    public var optional: Approvers
    public var involved: Approvers
    public var quote: Int?
    public var quorum: Int
    public struct Approvers: Codable {
      public var all: Set<String>?
      public var done: Set<String>?
      public var miss: Set<String>?
      public var hold: Set<String>?
      public init(approval: Approval, members: Set<String>, award: String) {
        let awarders = approval.awarders[award].or([])
        self.all = members
        self.done = members.intersection(awarders)
        self.miss = members.subtracting(awarders)
        self.hold = members.intersection(approval.holders)
        if case true = done?.isEmpty { done = nil }
        if case true = miss?.isEmpty { miss = nil }
        if case true = hold?.isEmpty { hold = nil }
      }
    }
  }
}
