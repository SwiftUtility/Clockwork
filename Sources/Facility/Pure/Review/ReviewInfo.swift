import Foundation
import Facility
extension Review {
  public struct Info: Encodable {
    public var iid: UInt
    public var authors: [String]?
    public var teams: [String]?
    public var phase: Phase?
    public var emergent: Bool
    public var approvers: [Approver]?
    public var problems: Problems?
    public init(state: State) {
      self.iid = state.review
      self.authors = state.authors.sorted().notEmpty
      self.teams = state.teams.sorted().notEmpty
      self.phase = state.phase
      self.emergent = state.emergent != nil
      var approvers = state.approves.mapValues(Approver.present(reviewer:))
      for approver in state.approvers {
        guard approvers[approver] == nil else { continue }
        approvers[approver] = .init(login: approver, miss: true)
      }
      if state.problems.get([]).isEmpty.not { self.problems = .init() }
      for problem in state.problems.get([]) {
        self.problems?.register(problem: problem)
        switch problem {
        case .discussions(let value): for (user, count) in value {
          approvers[user, default: .init(login: user, miss: false)].comments = count
        }
        case .holders(let value): for user in value {
          approvers[user, default: .init(login: user, miss: false)].hold = true
        }
        default: break
        }
      }
      self.approvers = approvers.values.sorted(\.login).notEmpty
    }
    public struct Approver: Encodable {
      public var login: String
      public var miss: Bool
      public var fragil: Bool = false
      public var advance: Bool = false
      public var diff: String? = nil
      public var hold: Bool = false
      public var comments: Int? = nil
      static func present(reviewer: Review.Approve) -> Self { .init(
        login: reviewer.login,
        miss: false,
        fragil: reviewer.resolution.fragil,
        advance: reviewer.resolution.approved && reviewer.resolution.fragil.not,
        diff: reviewer.resolution.approved.not.then(reviewer.commit.value)
      )}
    }
    public struct Problems: Encodable {
      public var badSource: String? = nil
      public var targetNotProtected: Bool = false
      public var targetMismatch: String? = nil
      public var sourceIsProtected: Bool = false
      public var multipleKinds: [String]? = nil
      public var undefinedKind: Bool = false
      public var authorIsBot: Bool = false
      public var authorIsNotBot: String? = nil
      public var sanity: String? = nil
      public var extraCommits: [String]? = nil
      public var notCherry: Bool = false
      public var notForward: Bool = false
      public var forkInTarget: Bool = false
      public var forkNotProtected: Bool = false
      public var forkNotInSource: Bool = false
      public var forkParentNotInTarget: Bool = false
      public var sourceNotAtFrok: Bool = false
      public var conflicts: Bool = false
      public var squashCheck: Bool = false
      public var draft: Bool = false
      public var discussions: Bool = false
      public var badTitle: Bool = false
      public var taskMismatch: Bool = false
      public var holders: Bool = false
      public var unknownUsers: [String]? = nil
      public var unknownTeams: [String]? = nil
      public var confusedTeams: [String]? = nil
      public var orphaned: [String]? = nil
      public var unapprovableTeams: [String]? = nil
      mutating func register(problem: Review.Problem) {
        switch problem {
        case .badSource(let value): badSource = value
        case .targetNotProtected: targetNotProtected = true
        case .targetMismatch(let value): targetMismatch = value.name
        case .sourceIsProtected: sourceIsProtected = true
        case .multipleKinds(let value): multipleKinds = value.sortedNonEmpty
        case .undefinedKind: undefinedKind = true
        case .authorIsBot: authorIsBot = true
        case .authorIsNotBot(let value): authorIsNotBot = value
        case .sanity(let value): sanity = value
        case .extraCommits(let value): extraCommits = value.map(\.name).sortedNonEmpty
        case .notCherry: notCherry = true
        case .notForward: notForward = true
        case .forkInTarget: forkInTarget = true
        case .forkNotProtected: forkNotProtected = true
        case .forkNotInSource: forkNotInSource = true
        case .forkParentNotInTarget: forkParentNotInTarget = true
        case .sourceNotAtFrok: sourceNotAtFrok = true
        case .conflicts: conflicts = true
        case .squashCheck: squashCheck = true
        case .draft: draft = true
        case .discussions: discussions = true
        case .badTitle: badTitle = true
        case .taskMismatch: taskMismatch = true
        case .holders: holders = true
        case .unknownUsers(let value): unknownUsers = value.sortedNonEmpty
        case .unknownTeams(let value): unknownTeams = value.sortedNonEmpty
        case .confusedTeams(let value): confusedTeams = value.sortedNonEmpty
        case .orphaned(let value): orphaned = value.sortedNonEmpty
        case .unapprovableTeams(let value): unapprovableTeams = value.sortedNonEmpty
        }
      }
    }
  }
}
