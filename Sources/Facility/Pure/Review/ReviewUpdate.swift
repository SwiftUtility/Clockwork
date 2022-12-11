import Foundation
import Facility
extension Review {
  public struct Update {
    let merge: Json.GitlabReviewState
    var state: Storage.State
    var fusion: Fusion?
    var problems: [Problem] = []
    var blockers: [Blocker] = []
    var diffTeams: Set<String> = []
    var authorshipTeams: Set<String> = []
    var sourceTeams: Set<String> = []
    var targetTeams: Set<String> = []
    var randomTeams: Set<String> = []
    var changedTeams: [Git.Sha: Set<String>] = [:]
    var childCommits: [Git.Sha: Set<Git.Sha>] = [:]
    public mutating func block(by blocker: Blocker) {
      blockers.append(blocker)
      state.phase = .block
      state.emergent = nil
      state.verified = nil
    }
    public mutating func stuck(by problem: Problem) {
      problems.append(problem)
      if state.phase != .block { state.phase = .stuck }
    }
//    public mutating func update(awards: [Json.GitlabAward]) {
//      let holdAwarders = awards
//        .filter({ $0.name == ctx.rules.hold })
//        .reduce(into: Set(), { $0.insert($1.user.username) })
//      if holdAwarders.intersection(ctx.bots).isEmpty { addAwards.insert(ctx.rules.hold) }
//      holders = holdAwarders
//        .subtracting(ctx.bots)
//        .intersection(ctx.users.values.filter(\.active).map(\.login))
//      if holders.isEmpty.not { blockers.append(.holders(holders)) }
//    }
//    public mutating func update(discussions: [Json.GitlabDiscussion]) {
//      for discussion in discussions {
//        guard discussion.notes.compactMap(\.resolved).contains(false) else { continue }
//        guard let note = discussion.notes.first else { continue }
//        commenters[note.author.username] = commenters[note.author.username]
//          .get([])
//          .union([discussion.id])
//      }
//    }
    mutating func checkProblems(
      awards: [Json.GitlabAward],
      discussions: [Json.GitlabDiscussion]
    ) {
      if state.squash != merge.squash { problems.append(.squashCheck) }
      if merge.draft { problems.append(.draft) }
      if merge.blockingDiscussionsResolved.not { problems.append(.discussions) }
      if case .propose(let propose)? = fusion {
        if let title = propose.proposition.title, title.isMet(merge.title).not
        { problems.append(.badTitle) }
        if let task = propose.proposition.task {
          let source = merge.sourceBranch.find(matches: task)
          let title = merge.title.find(matches: task)
          if Set(source).symmetricDifference(title).isEmpty.not { problems.append(.taskMismatch) }
        }
      }
    }
    public mutating func register(ctx: Context, sha: Git.Sha, diff: [String]) {
      guard diff.isEmpty.not else { return }
      changedTeams[sha] = diffTeams.filter({ ctx.ownage[$0]
        .map({ diff.contains(where: $0.isMet(_:)) })
        .get(false)
      })
    }
    public mutating func register(sha: Git.Sha, childs commits: [Git.Sha]) {
      childCommits[sha] = Set(commits)
    }
    public mutating func check(
      ctx: Context,
      diff: [String]
    ) -> Bool {
      guard let fusion = fusion, blockers.isEmpty else { return false }
      for blocker in ctx.check(state: state, fusion: fusion) { block(by: blocker) }
      if fusion.proposition {
        if ctx.bots.contains(merge.author.username) { block(by: .authorIsBot) }
      } else if ctx.bots.contains(merge.author.username).not {
        block(by: .authorIsNotBot(merge.author.username))
      }
      sourceTeams = ctx.rules.sourceBranch.filter({ $0.value.isMet(fusion.source.name) }).keySet
      targetTeams = ctx.rules.targetBranch.filter({ $0.value.isMet(fusion.target.name) }).keySet
      diffTeams = ctx.ownage.filter({ diff.contains(where: $0.value.isMet(_:)) }).keySet
      if fusion.proposition {
        authorshipTeams = ctx.rules.authorship
          .filter({ $0.value.intersection(state.authors).isEmpty.not })
          .keySet
      }
      let approvable = diffTeams
        .union(sourceTeams)
        .union(targetTeams)
        .union(authorshipTeams)
      if fusion.proposition {
        randomTeams = ctx.rules.randoms
          .filter({ $0.value.intersection(approvable).isEmpty.not })
          .keySet
      }
      var outdaters = approvable.subtracting(state.teams)
      if fusion.target != state.target {
        outdaters.formUnion(targetTeams)
      }
      state.reviewers = outdaters
        .flatMap({ ctx.rules.teams[$0]?.approvers ?? [] })
        .reduce(into: state.reviewers, { $0[$1]?.resolution = .obsolete })
      state.teams = approvable
      return blockers.isEmpty
    }
    public mutating func check(
      branches: [Json.GitlabBranch]
    ) -> Bool {
      guard let fusion = fusion else { return false }
      let protected = branches
        .filter(\.protected)
        .reduce(into: [:], { $0[$1.name] = $1 })
      if protected[fusion.target.name] == nil { block(by: .targetNotProtected) }
      if protected[fusion.source.name] != nil { block(by: .sourceIsProtected) }
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
        block(by: .badSource(prefix))
        return []
      }
      if source != fusion.source { block(by: .targetMismatch) }
      return [fusion]
    }
    public static func make(
      merge: Json.GitlabReviewState,
      review: Review,
      storage: Storage
    ) throws -> Self? {
      let source = try Git.Branch.make(name: merge.sourceBranch)
      let target = try Git.Branch.make(name: merge.targetBranch)
      var result: Self
      if let state = storage.states[merge.iid] {
        result = .init(merge: merge, state: state)
      } else {
        guard merge.state != "closed" else { return nil }
        result = .init(merge: merge, state: .init(
          review: merge.iid,
          target: target,
          authors: [merge.author.username]
        ))
      }
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
      if let propogate = result.state.propogate { fusions += result.makeFusion(
        prefix: .propogate, review: review, source: source, target: target, original: propogate
      )}
      for proposition in review.propositions.values {
        guard proposition.source.isMet(source.name) else { continue }
        fusions.append(.propose(.init(source: source, target: target, proposition: proposition)))
      }
      if fusions.count > 1 { result.block(by: .multipleKinds(fusions.map(\.kind))) }
      if fusions.isEmpty { result.block(by: .undefinedKind) }
      result.fusion = fusions.first
      return result
    }
    public static func make(
      merge: Json.GitlabReviewState,
      fusion: Fusion,
      authors: Set<String>
    ) -> Self {
      var result = Self(
        merge: merge,
        state: .init(review: merge.iid, target: fusion.target, authors: authors),
        fusion: fusion
      )
      if fusion.replication { result.state.replicate = fusion.original }
      if fusion.integration { result.state.integrate = fusion.original }
      if fusion.duplication { result.state.duplicate = fusion.original }
      if fusion.propogation { result.state.propogate = fusion.original }
      if fusion.autoApproveFork, let fork = fusion.fork { result.state.reviewers = authors
        .reduce(into: [:], { $0[$1] = .init(login: $1, commit: fork, resolution: .fragil) })
      }
      return result
    }
    public enum Blocker {
      case badSource(Fusion.Prefix)
      case targetNotProtected
      case targetMismatch
      case sourceIsProtected
      case multipleKinds([String])
      case undefinedKind
      case authorIsBot
      case authorIsNotBot(String)
      case unknownUsers(Set<String>)
      case unknownTeams(Set<String>)
      case confusedTeams(Set<String>)
      case sanity(String)
      case extraCommits(Set<Git.Branch>)
      case orphaned(Set<String>)
      case unapprovable(Set<String>)
      case conflicts
      case obsolete
    }
    public enum Problem {
      case squashCheck
      case draft
      case discussions
      case badTitle
      case taskMismatch
      case holders(Set<String>)
    }
  }
}
