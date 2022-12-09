import Foundation
import Facility
extension Review {
  public struct Update {
    var state: Storage.State
    var fusion: Fusion?
    var problems: [Problem] = []
    var blockers: [Blocker] = []
    public mutating func check(
      ctx: Approval.Context,
      profile: Configuration.Profile
    ) -> Bool {
      guard let sanity = ctx.rules.sanity else { return blockers.isEmpty }
      if
        let sanity = ctx.ownage[sanity],
        let codeOwnage = profile.codeOwnage,
        sanity.isMet(profile.location.path.value),
        sanity.isMet(codeOwnage.path.value)
      {} else { blockers.append(.sanity(sanity)) }
      if blockers.isEmpty.not { state.block() }
      return blockers.isEmpty
    }
    public mutating func check(
      ctx: Approval.Context,
      gitlab: Gitlab
    ) -> Bool {
      let unknownUsers = state.authors
        .union(state.reviewers.keys)
        .union(ctx.rules.ignore.keys)
        .union(ctx.rules.ignore.flatMap(\.value))
        .union(ctx.rules.authorship.flatMap(\.value))
        .union(ctx.rules.teams.flatMap(\.value.approvers))
        .union(ctx.rules.teams.flatMap(\.value.random))
        .subtracting(ctx.users.keys)
      if unknownUsers.isEmpty.not { blockers.append(.unknownUsers(unknownUsers)) }
      let unknownTeams = Set(ctx.rules.sanity.array)
        .union(ctx.ownage.keys)
        .union(ctx.rules.targetBranch.keys)
        .union(ctx.rules.sourceBranch.keys)
        .union(ctx.rules.authorship.keys)
        .union(ctx.rules.randoms.keys)
        .union(ctx.rules.randoms.flatMap(\.value))
        .filter { ctx.rules.teams[$0] == nil }
      if unknownTeams.isEmpty.not { blockers.append(.unknownTeams(unknownTeams)) }
      if blockers.isEmpty.not { state.block() }
      return blockers.isEmpty
    }
    public func checkGit(branches: [Json.GitlabBranch]) throws -> GitCheck? {
      guard let fusion = fusion else { return nil }
      guard fusion.duplication.not, fusion.propogation.not else { return nil }
      return try .init(
        protected: branches
          .filter(\.protected)
          .map(\.name)
          .map(Git.Branch.make(name:))
          .filter({ $0 != fusion.target }),
        fork: fusion.fork
      )
    }
    public mutating func check(
      branches: [Json.GitlabBranch]
    ) -> Bool {
      guard let fusion = fusion else { return false }
      let protected = branches
        .filter(\.protected)
        .reduce(into: [:], { $0[$1.name] = $1 })
      if let target = protected[fusion.target.name] {
        if fusion.replication, target.default.not { blockers.append(.targetNotDefault) }
      } else {
        blockers.append(.targetNotProtected)
      }
      if protected[fusion.source.name] != nil { blockers.append(.sourceIsProtected) }
      if blockers.isEmpty.not { state.block() }
      return blockers.isEmpty
    }
    public mutating func check(
      bot: Json.GitlabUser,
      merge: Json.GitlabReviewState
    ) -> Bool {
      guard let fusion = fusion else { return false }
      if fusion.proposition {
        if bot.username == merge.author.username { blockers.append(.authorIsBot) }
      } else {
        if bot.username != merge.author.username { blockers.append(.authorIsNotBot) }
      }
      if blockers.isEmpty.not { state.block() }
      return blockers.isEmpty
    }
    mutating func makeFusion(
      prefix: Fusion.Prefix,
      review: Review,
      source: Git.Branch,
      target: Git.Branch,
      original: Git.Branch
    ) -> [Fusion] {
      let components = source.name.components(separatedBy: "/")
      guard
        components.isEmpty.not,
        components[0] == prefix.rawValue,
        let fusion = try? prefix.makeFusion(
          review: review,
          fork: .make(value: components.end),
          target: target,
          original: original
      ) else {
        blockers.append(.badSource(prefix))
        state.block()
        return []
      }
      guard source == fusion.source else {
        blockers.append(.targetMismatch)
        state.block()
        return []
      }
      return [fusion]
    }
    public static func make(
      merge: Json.GitlabReviewState,
      review: Review,
      storage: Storage
    ) throws -> Self {
      let source = try Git.Branch.make(name: merge.sourceBranch)
      let target = try Git.Branch.make(name: merge.targetBranch)
      var result = Self(
        state: storage.states[merge.iid]
          .get(.init(review: merge.iid, target: target, authors: [merge.author.username]))
      )
      var fusions: [Fusion] = []
      if let replicate = result.state.replicate { fusions += result.makeFusion(
        prefix: .replicate, review: review, source: source, target: target, original: replicate
      )}
      if let integrate = result.state.integrate { fusions += result.makeFusion(
        prefix: .integrate, review: review, source: source, target: target, original: integrate
      )}
      if let duplicate = result.state.duplicate { fusions += result.makeFusion(
        prefix: .duplicate, review: review, source: source, target: target, original: duplicate
      )}
      for proposition in review.propositions.values {
        guard proposition.source.isMet(source.name) else { continue }
        fusions.append(.propose(.init(source: source, target: target, proposition: proposition)))
      }
      if fusions.count > 1 { result.blockers.append(.multipleKinds(fusions.map(\.kind))) }
      if fusions.isEmpty { result.blockers.append(.undefinedKind) }
      result.fusion = fusions.first
      if result.blockers.isEmpty.not { result.state.block() }
      return result
    }
    public static func make(
      merge: Json.GitlabReviewState,
      fusion: Fusion,
      authors: Set<String>
    ) -> Self {
      var result = Self(
        state: .init(review: merge.iid, target: fusion.target, authors: authors),
        fusion: fusion
      )
      if fusion.replication { result.state.replicate = fusion.original }
      if fusion.integration { result.state.integrate = fusion.original }
      if fusion.duplication { result.state.duplicate = fusion.original }
      if fusion.autoApproveFork, let fork = fusion.fork { result.state.reviewers = authors
        .reduce(into: [:], { $0[$1] = .init(login: $1, commit: fork, resolution: .fragil) })
      }
      return result
    }
    public enum Blocker {
      case badSource(Fusion.Prefix)
      case targetNotProtected
      case targetNotDefault
      case targetMismatch
      case sourceIsProtected
      case multipleKinds([String])
      case undefinedKind
      case authorIsBot
      case authorIsNotBot
      case unknownUsers(Set<String>)
      case unknownTeams(Set<String>)
      case sanity(String)
      case extraCommits(Set<Git.Branch>)
      case orphaned(Set<String>)
      case unapprovable(Set<String>)
    }
    public enum Problem {

    }
  }
}
