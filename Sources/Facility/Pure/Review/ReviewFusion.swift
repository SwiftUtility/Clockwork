import Foundation
import Facility
extension Review {
  public enum Fusion {
    case propose(Propose)
    case replicate(Replicate)
    case integrate(Integrate)
    case duplicate(Duplicate)
    case propogate(Propogate)
    public var proposition: Bool {
      if case .propose = self { return true } else { return false }
    }
    public var replication: Bool {
      if case .replicate = self { return true } else { return false }
    }
    public var integration: Bool {
      if case .integrate = self { return true } else { return false }
    }
    public var duplication: Bool {
      if case .duplicate = self { return true } else { return false }
    }
    public var propogation: Bool {
      if case .propogate = self { return true } else { return false }
    }
    public var kind: String {
      switch self {
      case .propose(let propose): return propose.proposition.name
      case .replicate: return Prefix.replicate.rawValue
      case .integrate: return Prefix.integrate.rawValue
      case .duplicate: return Prefix.duplicate.rawValue
      case .propogate: return Prefix.propogate.rawValue
      }
    }
    public var target: Git.Branch {
      switch self {
      case .propose(let propose): return propose.target
      case .replicate(let replicate): return replicate.target
      case .integrate(let integrate): return integrate.target
      case .duplicate(let duplicate): return duplicate.target
      case .propogate(let propogate): return propogate.target
      }
    }
    public var source: Git.Branch {
      switch self {
      case .propose(let propose): return propose.source
      case .replicate(let replicate): return replicate.source
      case .integrate(let integrate): return integrate.source
      case .duplicate(let duplicate): return duplicate.source
      case .propogate(let propogate): return propogate.source
      }
    }
    public var fork: Git.Sha? {
      switch self {
      case .propose: return nil
      case .replicate(let replicate): return replicate.fork
      case .integrate(let integrate): return integrate.fork
      case .duplicate(let duplicate): return duplicate.fork
      case .propogate(let propogate): return propogate.fork
      }
    }
    public var original: Git.Branch? {
      switch self {
      case .propose: return nil
      case .replicate(let replicate): return replicate.original
      case .integrate(let integrate): return integrate.original
      case .duplicate(let duplicate): return duplicate.original
      case .propogate(let propogate): return propogate.original
      }
    }
    public var autoApproveFork: Bool {
      switch self {
      case .propose: return false
      case .replicate(let replicate): return replicate.replication.allowOrphaned
      case .integrate(let integrate): return integrate.integration.allowOrphaned
      case .duplicate(let duplicate): return duplicate.duplication.allowOrphaned
      case .propogate(let propogate): return propogate.propogation.allowOrphaned
      }
    }
    public var allowOrphaned: Bool {
      switch self {
      case .propose: return false
      case .replicate(let replicate): return replicate.replication.autoApproveFork
      case .integrate(let integrate): return integrate.integration.autoApproveFork
      case .duplicate(let duplicate): return duplicate.duplication.autoApproveFork
      case .propogate(let propogate): return propogate.propogation.autoApproveFork
      }
    }
    public func gitCheck(branches: [Json.GitlabBranch]) throws -> GitCheck {
      let target = target
      let branches = try branches
        .filter(\.protected)
        .map(\.name)
        .map(Git.Branch.make(name:))
        .filter({ $0 != target })
      switch self {
      case .propose: return .extras(branches, [])
      case .replicate(let replicate): return .extras(branches, [replicate.fork])
      case .integrate(let integrate): return .extras(branches, [integrate.fork])
      case .duplicate(let duplicate): return .cherry(duplicate.fork)
      case .propogate(let propogate): return .forward(propogate.fork)
      }
    }
//    public struct Infusion {
//      public let review: Review
//      public let merge: Json.GitlabReviewState
//      public var state: Storage.State
//      public var fusion: Fusion?
//      public var confusions: [Confusion] = []
//      public var protected: Set<Git.Branch> = []
//      public mutating func update(
//        ctx: Approval.Context,
//        profile: Configuration.Profile
//      ) {
//        let unknownUsers = state.authors
//          .union(state.reviewers.keys)
//          .union(ctx.haters.keys)
//          .union(ctx.haters.flatMap(\.value))
//          .union(ctx.rules.authorship.flatMap(\.value))
//          .union(ctx.rules.teams.flatMap(\.value.approvers))
//          .union(ctx.rules.teams.flatMap(\.value.random))
//          .subtracting(ctx.users.keys)
//        if unknownUsers.isEmpty.not { confusions.append(.unknownUsers(unknownUsers)) }
//        let unknownTeams = Set(ctx.rules.sanity.array)
//          .union(ctx.ownage.keys)
//          .union(ctx.rules.targetBranch.keys)
//          .union(ctx.rules.sourceBranch.keys)
//          .union(ctx.rules.authorship.keys)
//          .union(ctx.rules.randoms.keys)
//          .union(ctx.rules.randoms.flatMap(\.value))
//          .filter { ctx.rules.teams[$0] == nil }
//        if unknownTeams.isEmpty.not { confusions.append(.unknownTeams(unknownTeams)) }
//        if let sanity = ctx.rules.sanity {
//          if
//            let sanity = ctx.ownage[sanity],
//            sanity.isMet(profile.location.path.value),
//            let codeOwnage = profile.codeOwnage,
//            sanity.isMet(codeOwnage.path.value)
//          {} else { confusions.append(.sanity(sanity)) }
//        }
//      }
//      public mutating func update(branches: [Json.GitlabBranch]) throws {
//        guard let fusion = fusion else { return }
//        protected = try branches
//          .filter(\.protected)
//          .map(\.name)
//          .map(Git.Branch.make(name:))
//          .reduce(into: [], { $0.insert($1) })
//        if protected.contains(fusion.target).not { confusions.append(.targetNotProtected) }
//        if protected.contains(fusion.source) { confusions.append(.sourceIsProtected) }
//      }
//      public mutating func update(gitlab: Gitlab) throws {
//        guard let fusion = fusion else { return }
//        let bot = try gitlab.rest.get().user
//        if fusion.replication {
//          let defaultBranch = try gitlab.project.get().defaultBranch
//          if defaultBranch != fusion.target.name { confusions.append(.targetNotDefault) }
//        }
//        if fusion.proposition {
//          if bot.username == merge.author.username { confusions.append(.authorIsBot) }
//        } else {
//          if bot.username != merge.author.username { confusions.append(.authorIsNotBot) }
//        }
//      }
//      public static func make(
//        review: Review,
//        profile: Configuration.Profile,
//        state: Storage.State,
//        ctx: Approval.Context,
//        gitlab: Gitlab,
//        branches: [Json.GitlabBranch]
//      ) throws -> Self {
//        let merge = try gitlab.review.get()
//        var result = Fusion.Infusion(review: review, merge: merge, state: state)
//        let source = try Git.Branch.make(name: merge.sourceBranch)
//        let target = try Git.Branch.make(name: merge.targetBranch)
//        var fusions: [Fusion] = []
//        if let replicate = state.replicate {
//          fusions += Prefix.replicate.makeFusion(
//            infusion: &result, source: source, target: target, original: replicate
//          )
//        }
//        if let integrate = state.integrate {
//          fusions += Prefix.integrate.makeFusion(
//            infusion: &result, source: source, target: target, original: integrate
//          )
//        }
//        if let duplicate = state.duplicate {
//          fusions += Prefix.duplicate.makeFusion(
//            infusion: &result, source: source, target: target, original: duplicate
//          )
//        }
//        for proposition in review.propositions.values {
//          guard proposition.source.isMet(source.name) else { continue }
//          fusions.append(.propose(.init(source: source, target: target, proposition: proposition)))
//        }
//        if fusions.count > 1 { result.confusions.append(.multipleKinds(fusions.map(\.kind))) }
//        if fusions.isEmpty { result.confusions.append(.undefinedKind) }
//        result.fusion = fusions.last
//        try result.update(gitlab: gitlab)
//        try result.update(branches: branches)
//        result.update(ctx: ctx, profile: profile)
//        if result.confusions.isEmpty.not { result.state.stop() }
//        return result
//      }
//    }
//    public enum Confusion {
//      case badSource(Fusion.Prefix)
//      case targetNotProtected
//      case targetNotDefault
//      case targetMismatch
//      case sourceIsProtected
//      case multipleKinds([String])
//      case undefinedKind
//      case authorIsBot
//      case authorIsNotBot
//      case unknownUsers(Set<String>)
//      case unknownTeams(Set<String>)
//      case sanity(String)
//      case extraCommits([String])
//      case orphaned([String])
//      case unapprovable([String])
//    }
    public struct Propose {
      public var source: Git.Branch
      public var target: Git.Branch
      public var proposition: Proposition
    }
    public struct Replicate {
      public var fork: Git.Sha
      public var source: Git.Branch
      public var target: Git.Branch
      public var original: Git.Branch
      public var replication: Replication
    }
    public struct Integrate {
      public var fork: Git.Sha
      public var source: Git.Branch
      public var target: Git.Branch
      public var original: Git.Branch
      public var integration: Integration
    }
    public struct Duplicate {
      public var fork: Git.Sha
      public var source: Git.Branch
      public var target: Git.Branch
      public var original: Git.Branch
      public var duplication: Duplication
    }
    public struct Propogate {
      public var fork: Git.Sha
      public var source: Git.Branch
      public var target: Git.Branch
      public var original: Git.Branch
      public var propogation: Propogation
    }
    public enum GitCheck {
      case extras([Git.Branch], [Git.Sha])
      case cherry(Git.Sha)
      case forward(Git.Sha)
    }
    public enum Prefix: String {
      case replicate
      case integrate
      case duplicate
      case propogate
      public func makeFusion(
        review: Review,
        fork: Git.Sha,
        target: Git.Branch,
        original: Git.Branch
      ) throws -> Fusion {
        switch self {
        case .replicate: return try .replicate(.init(
          fork: fork,
          source: .make(name: makeSource(target: target, fork: fork)),
          target: target,
          original: original,
          replication: review.replication
        ))
        case .integrate: return try .integrate(.init(
          fork: fork,
          source: .make(name: makeSource(target: target, fork: fork)),
          target: target,
          original: original,
          integration: review.integration
        ))
        case .duplicate: return try .duplicate(.init(
          fork: fork,
          source: .make(name: makeSource(target: target, fork: fork)),
          target: target,
          original: original,
          duplication: review.duplication
        ))
        case .propogate: return try .propogate(.init(
          fork: fork,
          source: .make(name: makeSource(target: target, fork: fork)),
          target: target,
          original: original,
          propogation: review.propogation
        ))
        }
      }
      func makeSource(target: Git.Branch, fork: Git.Sha) -> String {
        "\(rawValue)/\(target.name)/\(fork.value)"
      }
//      func makeFork(source: Git.Branch) throws -> Git.Sha {
//        switch self {
//        case .replicate: return "\(rawValue)/\(fork.value)"
//        case .integrate, .duplicate: return "\(rawValue)/\(target.name)/\(fork.value)"
//        }
//      }

//      func makeFusion(
//        update: inout Update,
//        review: Review,
//        source: Git.Branch,
//        target: Git.Branch,
//        original: Git.Branch
//      ) -> [Fusion] {
//        let components = source.name.components(separatedBy: "/")
//        guard components.isEmpty.not, components[0] == rawValue, let fusion = try? makeFusion(
//          review: review, fork: .make(value: components.end), target: target, original: original
//        ) else {
//          update.blockers.append(.badSource(self))
//          return []
//        }
//        guard source == fusion.source else {
//          update.blockers.append(.targetMismatch)
//          return []
//        }
//        return [fusion]
//      }
    }
  }
}
