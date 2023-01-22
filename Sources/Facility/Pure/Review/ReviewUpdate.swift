import Foundation
import Facility
extension Review {
  public struct Update {
    public internal(set) var head: Git.Sha
    public internal(set) var merge: Json.GitlabMergeState
    public internal(set) var ownage: [String: Criteria]
    public internal(set) var state: Storage.State
    public internal(set) var fusion: Fusion?
    public internal(set) var problems: [Problem] = []
    public internal(set) var addAward: String? = nil
    public mutating func makeGitCheck(
      branches: [Json.GitlabBranch]
    ) throws -> [Fusion.GitCheck] {
      guard let fusion = fusion, problems.contains(where: \.blocking).not else { return [] }
      var protected = branches
        .filter(\.protected)
        .reduce(into: [:], { $0[$1.name] = $1 })
      if protected[fusion.source.name] != nil { add(problem: .sourceIsProtected) }
      if protected[fusion.target.name] == nil { add(problem: .targetNotProtected) }
      protected[fusion.target.name] = nil
      switch fusion {
      case .propose(let propose): return try [
        .extraCommits(
          branches: protected.values
            .map(\.name)
            .map(Git.Branch.make(name:)),
          exclude: [.make(remote: propose.target)],
          head: head
        ),
      ]
      case .replicate(let replicate): return try [
        .extraCommits(
          branches: protected.values
            .map(\.name)
            .map(Git.Branch.make(name:)),
          exclude: [.make(remote: replicate.target), .make(sha: replicate.fork)],
          head: head
        ),
        .forkInTarget(fork: replicate.fork, target: replicate.target),
        .forkNotInOriginal(fork: replicate.fork, original: replicate.original),
        .forkNotInSource(fork: replicate.fork, head: head),
        .forkParentNotInTarget(fork: replicate.fork, target: replicate.target),
      ]
      case .integrate(let integrate): return try [
        .extraCommits(
          branches: protected.values
            .map(\.name)
            .map(Git.Branch.make(name:)),
          exclude: [.make(remote: integrate.target), .make(sha: integrate.fork)],
          head: head
        ),
        .forkInTarget(fork: integrate.fork, target: integrate.target),
        .forkNotInOriginal(fork: integrate.fork, original: integrate.original),
        .forkNotInSource(fork: integrate.fork, head: head),
      ]
      case .duplicate(let duplicate): return [
        .notCherry(fork: duplicate.fork, head: head, target: duplicate.target),
        .forkInTarget(fork: duplicate.fork, target: duplicate.target),
        .forkNotInOriginal(fork: duplicate.fork, original: duplicate.original),
      ]
      case .propogate(let propogate): return [
        .notForward(fork: propogate.fork, head: head, target: propogate.target),
        .forkInTarget(fork: propogate.fork, target: propogate.target),
        .forkNotInOriginal(fork: propogate.fork, original: propogate.original),
        .forkNotInSource(fork: propogate.fork, head: head),
      ]}
    }
    public mutating func update(
      ctx: Context,
      awards: [Json.GitlabAward],
      discussions: [Json.GitlabDiscussion]
    ) {
      if state.squash != merge.squash { add(problem: .squashCheck) }
      if merge.draft { add(problem: .draft) }
      if merge.blockingDiscussionsResolved.not {
        let discussions = discussions
          .compactMap({ $0.notes.first })
          .filter({ $0.resolvable && $0.resolved == false })
          .map(\.author.username)
          .reduce(into: [:], { $0[$1] = $0[$1].get(0) + 1 })
        add(problem: .discussions(discussions))
      }
      if case .propose(let propose) = fusion {
        if let criteria = propose.proposition.title {
          var title = merge.title
          title = (try? title.dropPrefix("Draft: ")) ?? title
          title = (try? title.dropPrefix("WIP: ")) ?? title
          if criteria.isMet(title).not { add(problem: .badTitle) }
        }
        if let task = propose.proposition.task {
          let source = merge.sourceBranch.find(matches: task)
          let title = merge.title.find(matches: task)
          if Set(source).symmetricDifference(title).isEmpty.not { add(problem: .taskMismatch) }
        }
      }
      var holders = awards
        .filter({ $0.name == ctx.rules.hold })
        .reduce(into: Set(), { $0.insert($1.user.username) })
      if holders.intersection(ctx.bots).isEmpty { addAward = ctx.rules.hold }
      holders = holders
        .subtracting(ctx.bots)
        .intersection(ctx.users.filter(\.value.active).keySet)
      if holders.isEmpty.not { add(problem: .holders(holders)) }
    }
    public func makeApprovesCheck() throws -> Fusion.ApprovesCheck? {
      guard let fusion = fusion, problems.contains(where: \.blocking).not else { return nil }
      guard state.emergent.flatMapNil(state.verified) != head else { return nil }
      switch fusion {
      case .propose(let propose): return .init(
        checkDiff: true,
        head: head,
        target: propose.target
      )
      case .replicate(let replicate): return .init(
        checkDiff: true,
        head: head,
        target: replicate.target,
        fork: replicate.fork
      )
      case .integrate(let integrate): return .init(
        checkDiff: true,
        head: head,
        target: integrate.target,
        fork: integrate.fork
      )
      case .duplicate(let duplicate): return .init(
        checkDiff: false,
        head: head,
        target: duplicate.target
      )
      case .propogate(let propogate): return .init(
        checkDiff: false,
        head: head,
        target: propogate.target
      )}
    }
    public mutating func update(
      ctx: Context,
      approvesCheck: Fusion.ApprovesCheck?
    ) {
      guard let fusion = fusion, problems.contains(where: \.blocking).not else { return }
      var changes = approvesCheck.map(\.changes).get([:])
      for (sha, diff) in changes {
        if state.skip.contains(sha) || diff.isEmpty { changes[sha] = nil }
      }
      let childs = approvesCheck.map(\.childs).get([:])
      let diff = approvesCheck.map(\.diff).get([])
      state.verified = nil
      state.emergent = state.emergent
        .flatMap({ childs[$0] })
        .flatMap({ $0.contains(where: { changes[$0] != nil }).else(head) })
      let sourceTeams = ctx.rules.sourceBranch
        .filter({ $0.value.isMet(fusion.source.name) })
        .keySet
      let targetTeams = ctx.rules.targetBranch
        .filter({ $0.value.isMet(fusion.target.name) })
        .keySet
      let diffTeams = fusion.diffApproval.then(ownage).get([:])
        .filter({ diff.contains(where: $0.value.isMet(_:)) })
        .keySet
      let authorshipTeams = fusion.authorshipApproval.then(ctx.rules.authorship).get([:])
        .filter({ $0.value.intersection(state.authors).isEmpty.not })
        .keySet
      let approvableTeams = diffTeams
        .union(sourceTeams)
        .union(targetTeams)
        .union(authorshipTeams)
      let randomTeams = fusion.randomApproval.then(ctx.rules.randoms).get([:])
        .filter({ $0.value.intersection(approvableTeams).isEmpty.not })
        .keySet
      let active = ctx.users.filter(\.value.active).keySet
        .subtracting(ctx.bots)
      state.authors = state.authors
        .subtracting(ctx.bots)
      if fusion.allowOrphaned.not, state.authors.intersection(active).isEmpty
      { add(problem: .orphaned(state.authors)) }
      state.legates = approvableTeams
        .compactMap({ ctx.rules.teams[$0] })
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .intersection(active)
        .intersection(state.legates)
      state.randoms = randomTeams
        .compactMap({ ctx.rules.teams[$0] })
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .intersection(active)
        .intersection(state.randoms)
      state.reviewers.keySet
        .subtracting(state.legates)
        .subtracting(state.randoms)
        .subtracting(state.authors)
        .forEach({ state.reviewers[$0] = nil })
      state.reviewers.values
        .filter({ childs[$0.commit] == nil })
        .forEach({ state.reviewers[$0.login] = nil })
      if let fork = fusion.autoApproveFork { state.authors
        .filter({ state.reviewers[$0] == nil })
        .forEach({ state.reviewers[$0] = .init(login: $0, commit: fork, resolution: .fragil) })
      }
      var brokenTeams = approvableTeams.subtracting(state.teams)
      state.teams = approvableTeams
      if fusion.target != state.target {
        brokenTeams.formUnion(targetTeams)
        state.target = fusion.target
      }
      brokenTeams
        .compactMap({ ctx.rules.teams[$0] })
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .forEach({ state.reviewers[$0]?.resolution = .obsolete })
      let fragilUtility = authorshipTeams
        .union(sourceTeams)
        .union(targetTeams)
        .compactMap({ ctx.rules.teams[$0] })
        .filter(\.advanceApproval.not)
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .intersection(state.legates)
      let fragilRandoms = randomTeams
        .compactMap({ ctx.rules.teams[$0] })
        .filter(\.advanceApproval.not)
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .intersection(state.randoms)
      let fragilUsers = state.authors
        .union(fragilUtility)
        .union(fragilRandoms)
        .union(state.reviewers.filter(\.value.resolution.fragil).keys)
      let fragilDiffApprovers = diffTeams
        .compactMap({ ctx.rules.teams[$0] })
        .filter(\.advanceApproval.not)
        .reduce(into: [:], { $0[$1.name] = $1.approvers })
      for reviewer in state.reviewers.values {
        guard let childs = childs[reviewer.commit] else {
          state.reviewers[reviewer.login] = nil
          continue
        }
        guard reviewer.resolution != .obsolete else { continue }
        let breakers = childs.compactMap({ changes[$0] })
        guard breakers.isEmpty.not else { continue }
        guard fragilUsers.contains(reviewer.login) else {
          state.reviewers[reviewer.login]?.resolution = .obsolete
          continue
        }
        for fragilUsers in breakers
          .reduce(into: Set(), { $0.formUnion($1) })
          .compactMap({ fragilDiffApprovers[$0] })
        {
          guard fragilUsers.contains(reviewer.login) else { continue }
          state.reviewers[reviewer.login]?.resolution = .obsolete
          break
        }
      }
      let unknownUsers = state.authors
        .union(state.reviewers.keys)
        .union(ctx.rules.ignore.keys)
        .union(ctx.rules.ignore.flatMap(\.value))
        .union(ctx.rules.authorship.flatMap(\.value))
        .union(ctx.rules.teams.flatMap(\.value.approvers))
        .union(ctx.rules.teams.flatMap(\.value.random))
        .subtracting(ctx.users.keys)
        .subtracting(ctx.bots)
      if unknownUsers.isEmpty.not { add(problem: .unknownUsers(unknownUsers)) }
      let unknownTeams = Set(ctx.rules.sanity.array)
        .union(ownage.keys)
        .union(ctx.rules.targetBranch.keys)
        .union(ctx.rules.sourceBranch.keys)
        .union(ctx.rules.authorship.keys)
        .union(ctx.rules.randoms.keys)
        .union(ctx.rules.randoms.flatMap(\.value))
        .filter({ ctx.rules.teams[$0] == nil })
      if unknownTeams.isEmpty.not { add(problem: .unknownTeams(unknownTeams)) }
      var confusedTeams = ownage.keySet
        .union(ctx.rules.sanity.array)
        .union(ctx.rules.targetBranch.keys)
        .union(ctx.rules.sourceBranch.keys)
        .union(ctx.rules.authorship.keys)
        .union(ctx.rules.randoms.flatMap(\.value))
        .compactMap({ ctx.rules.teams[$0] })
        .filter({ $0.random.isEmpty.not })
      confusedTeams += ctx.rules.randoms.keys
        .compactMap({ ctx.rules.teams[$0] })
        .filter({ $0.approvers.subtracting($0.random).isEmpty.not })
      if confusedTeams.isEmpty.not {
        add(problem: .confusedTeams(Set(confusedTeams.map(\.name))))
      }
      var legates = state.teams.compactMap({ ctx.rules.teams[$0] })
      legates.indices.forEach({ legates[$0].update(active: active) })
      var ignore = fusion.selfApproval.not.then(state.authors).get([])
      legates.indices.forEach({ legates[$0].update(exclude: ignore) })
      let unapprovable = legates
        .filter(\.isUnapprovable)
        .reduce(into: Set(), { $0.insert($1.name) })
      if unapprovable.isEmpty.not { add(problem: .unapprovableTeams(unapprovable)) }
      var randoms = randomTeams.compactMap({ ctx.rules.teams[$0] })
      randoms.indices.forEach({ randoms[$0].update(active: active) })
      ignore = ctx.rules.ignore
        .filter({ $0.value.intersection(state.authors).isEmpty.not })
        .keySet
        .union(state.authors)
      randoms.indices.forEach({ randoms[$0].update(exclude: ignore) })
      if problems.contains(where: \.verifiable.not).not {
        var involved = state.authors
          .union(state.legates)
          .union(state.randoms)
        let necessary = legates.reduce(into: Set(), { $0.formUnion($1.necessary) })
        state.legates.formUnion(necessary)
        involved.formUnion(necessary)
        legates.indices.forEach({ legates[$0].update(involved: involved) })
        state.legates.formUnion(selectUsers(
          ctx: ctx,
          teams: &legates,
          involved: &involved,
          users: legates.reduce(into: Set(), { $0.formUnion($1.approvers) })
        ))
        for index in randoms.indices { randoms[index].update(involved: involved) }
        state.randoms.formUnion(selectUsers(
          ctx: ctx,
          teams: &randoms,
          involved: &involved,
          users: randoms.reduce(into: Set(), { $0.formUnion($1.approvers) })
        ))
        state.verified = head
      }
      if problems.contains(where: \.blocking) {
        state.phase = .block
      } else if state.emergent == head {
        if problems.contains(where: \.skippable.not) {
          state.phase = .stuck
        } else {
          state.phase = .ready
        }
      } else if state.verified == head {
        if problems.isEmpty.not {
          state.phase = .stuck
        } else if state.isApproved {
          state.phase = .ready
        } else {
          state.phase = .amend
        }
      } else {
        state.phase = .stuck
      }
    }
    public mutating func add(problem: Problem) {
      problems.append(problem)
      if problem.blocking {
        state.phase = .block
        state.emergent = nil
        state.verified = nil
      }
      if state.phase != .block {
        if state.emergent == head, problem.skippable.not { state.phase = .stuck }
        if state.emergent == nil { state.phase = .stuck }
      }
    }
    func selectUsers(
      ctx: Context,
      teams: inout [Review.Team],
      involved: inout Set<String>,
      users: Set<String>
    ) -> Set<String> {
      var left = users
      while true {
        var weights: [String: Int] = [:]
        for user in left {
          let count = teams.filter({ $0.isNeeded(user: user) }).count
          guard count > 0 else { continue }
          weights[user] = count * ctx.rules.weights[user].get(ctx.rules.baseWeight)
        }
        guard let user = random(weights: weights) else { return users.subtracting(left) }
        left.remove(user)
        involved.insert(user)
        teams.indices.forEach({ teams[$0].update(involved: involved) })
      }
    }
    func random(weights: [String: Int]) -> String? {
      var acc = weights.values.reduce(0, +)
      guard acc > 0 else { return weights.keys.randomElement() }
      acc = Int.random(in: 0 ..< acc)
      return weights.keys.sorted().first(where: {
        acc -= weights[$0].get(0)
        return acc < 0
      })
    }
    mutating func makeFusion(
      ctx: Context,
      prefix: Fusion.Prefix,
      source: Git.Branch,
      target: Git.Branch
    ) -> [Fusion] {
      guard let original = state[keyPath: prefix.original] else { return [] }
      let components = source.name.components(separatedBy: "/")
      guard
        components.isEmpty.not,
        components[0] == prefix.rawValue,
        let fusion = try? prefix.makeFusion(
          review: ctx.review,
          fork: .make(value: components.end),
          target: target,
          original: original
        ) else {
        add(problem: .badSource(prefix))
        return []
      }
      if source != fusion.source { add(problem: .targetMismatch) }
      return [fusion]
    }
    public static func make(
      ctx: Context,
      merge: Json.GitlabMergeState,
      ownage: [String: Criteria],
      profile: Configuration.Profile,
      state: Storage.State
    ) throws -> Self {
      let source = try Git.Branch.make(name: merge.sourceBranch)
      let target = try Git.Branch.make(name: merge.targetBranch)
      var result = try Self(
        head: .make(merge: merge),
        merge: merge,
        ownage: ownage,
        state: state
      )
      if merge.targetBranch != state.target.name {
        result.state.emergent = nil
        result.state.verified = nil
      }
      var fusions: [Fusion] = []
      fusions += result.makeFusion(ctx: ctx, prefix: .duplicate, source: source, target: target)
      fusions += result.makeFusion(ctx: ctx, prefix: .integrate, source: source, target: target)
      fusions += result.makeFusion(ctx: ctx, prefix: .propogate, source: source, target: target)
      fusions += result.makeFusion(ctx: ctx, prefix: .replicate, source: source, target: target)
      fusions += ctx.review.propositions.values
        .compactMap({ $0.makePropose(source: source, target: target) })
      if let sanity = ctx.rules.sanity {
        if
          let sanity = ownage[sanity],
          let codeOwnage = profile.codeOwnage,
          sanity.isMet(profile.location.path.value),
          sanity.isMet(codeOwnage.path.value)
        {} else { result.add(problem: .sanity(sanity)) }
      }
      if fusions.count > 1 { result.add(problem: .multipleKinds(fusions.map(\.kind))) }
      if fusions.isEmpty { result.add(problem: .undefinedKind) }
      result.fusion = fusions.first
      guard let fusion = fusions.first else { return result }
      if fusion.proposition {
        if ctx.bots.contains(merge.author.username) { result.add(problem: .authorIsBot) }
      } else if ctx.bots.contains(merge.author.username).not {
        result.add(problem: .authorIsNotBot(merge.author.username))
      }
      return result
    }
    public enum Problem {
      case badSource(Fusion.Prefix)
      case targetNotProtected
      case targetMismatch
      case sourceIsProtected
      case multipleKinds([String])
      case undefinedKind
      case authorIsBot
      case authorIsNotBot(String)
      case sanity(String)
      case extraCommits(Set<Git.Branch>)
      case notCherry
      case notForward
      case forkInTarget
      case forkNotInOriginal
      case forkParentNotInTarget
      case sourceNotAtFrok
      case conflicts
      case obsolete
      case squashCheck
      case draft
      case discussions([String: Int])
      case badTitle
      case taskMismatch
      case holders(Set<String>)
      case unknownUsers(Set<String>)
      case unknownTeams(Set<String>)
      case confusedTeams(Set<String>)
      case orphaned(Set<String>)
      case unapprovableTeams(Set<String>)
      var blocking: Bool {
        switch self {
        case .badSource: return true
        case .targetNotProtected: return true
        case .targetMismatch: return true
        case .sourceIsProtected: return true
        case .multipleKinds: return true
        case .undefinedKind: return true
        case .authorIsBot: return true
        case .authorIsNotBot: return true
        case .sanity: return true
        case .extraCommits: return true
        case .notCherry: return true
        case .notForward: return true
        case .forkInTarget: return true
        case .forkNotInOriginal: return true
        case .forkParentNotInTarget: return true
        case .sourceNotAtFrok: return true
        case .conflicts: return true
        case .obsolete: return true
        default: return false
        }
      }
      var verifiable: Bool {
        switch self {
        case .squashCheck: return true
        case .draft: return true
        case .discussions: return true
        case .badTitle: return true
        case .taskMismatch: return true
        case .holders: return true
        default: return false
        }
      }
      var skippable: Bool {
        switch self {
        case .holders: return true
        case .unknownUsers: return true
        case .unknownTeams: return true
        case .confusedTeams: return true
        case .orphaned: return true
        case .unapprovableTeams: return true
        default: return false
        }
      }
    }
  }
}
