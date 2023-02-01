import Foundation
import Facility
extension Review {
  public struct State {
    public var review: UInt
    public var source: Git.Branch
    public var target: Git.Branch
    public var original: Git.Branch?
    public var authors: Set<String>
    public var phase: Phase? = nil
    public var skip: Set<Git.Sha> = []
    public var teams: Set<String> = []
    public var emergent: Git.Sha? = nil
    public var verified: Git.Sha? = nil
    public var randoms: Set<String> = []
    public var legates: Set<String> = []
    public var reviewers: [String: Reviewer] = [:]
    public var problems: [Problem]? = nil
    public var change: Change? = nil
    public var squash: Bool { original == nil }
    public mutating func add(problem: Problem) {
      problems = problems.get([]) + [problem]
      if problem.blocking {
        phase = .block
        emergent = nil
        verified = nil
      }
      if phase != .block {
        if emergent == nil || problem.skippable.not { phase = .stuck }
      }
    }
    public mutating func shiftHead(sha: Git.Sha) {
      if emergent != nil { emergent = sha }
      if verified != nil { verified = sha }
    }
    public mutating func squashApproves(sha: Git.Sha) {
      reviewers.keys.forEach({ reviewers[$0]?.commit = sha })
    }
    func isUnapproved(user: String) -> Bool {
      guard let user = reviewers[user] else { return true }
      return user.resolution.approved.not
    }
    var isApproved: Bool { authors
      .union(legates)
      .union(randoms)
      .contains(where: isUnapproved(user:))
      .not
    }
    public mutating func prepareChange(
      ctx: Context,
      merge: Json.GitlabMergeState,
      ownage: [String: Criteria],
      profile: Configuration.Profile
    ) throws -> Bool {
      let source = try Git.Branch.make(name: merge.sourceBranch)
      let target = try Git.Branch.make(name: merge.targetBranch)
      let head = try Git.Sha.make(merge: merge)
      if target != self.target {
        emergent = nil
        verified = nil
      }
      if source != self.source { add(problem: .badSource(self.source.name)) }
      if let sanity = ctx.rules.sanity {
        if
          let sanity = ownage[sanity],
          let codeOwnage = profile.codeOwnage,
          sanity.isMet(profile.location.path.value),
          sanity.isMet(codeOwnage.path.value)
        {} else { add(problem: .sanity(sanity)) }
      }
      if let original = original {
        if ctx.bots.contains(merge.author.username).not {
          add(problem: .authorIsNotBot(merge.author.username))
        }
        let components = source.name.components(separatedBy: "/")
        if let fusion = components.first
          .flatMap(Fusion.Prefix.init(rawValue:))
          .flatMap({ try? $0.makeFusion(
            review: ctx.review,
            fork: .make(value: components.end),
            target: target,
            original: original
          )})
        {
          change = .init(head: head, merge: merge, ownage: ownage, fusion: fusion)
          if source != fusion.source { add(problem: .targetMismatch) }
        } else {
          add(problem: .badSource(self.source.name))
        }
      } else {
        if ctx.bots.contains(merge.author.username) { add(problem: .authorIsBot) }
        let fusions = ctx.review.propositions.values
          .compactMap({ $0.makePropose(source: source, target: target) })
        if fusions.isEmpty { add(problem: .undefinedKind) }
        else if fusions.count > 1 { add(problem: .multipleKinds(fusions.map(\.kind))) }
        else if let fusion = fusions.first {
          change = .init(head: head, merge: merge, ownage: ownage, fusion: fusion)
        }
      }
      return change != nil
    }
    public mutating func makeGitCheck(
      branches: [Json.GitlabBranch]
    ) throws -> [Fusion.GitCheck] {
      guard let change = change else { return [] }
      var protected = branches
        .filter(\.protected)
        .reduce(into: [:], { $0[$1.name] = $1 })
      if protected[change.fusion.source.name] != nil { add(problem: .sourceIsProtected) }
      if protected[change.fusion.target.name] == nil { add(problem: .targetNotProtected) }
      guard problems.get([]).contains(where: \.blocking).not else { return [] }
      protected[change.fusion.target.name] = nil
      switch change.fusion {
      case .propose(let propose): return try [
        .extraCommits(
          branches: protected.values
            .map(\.name)
            .map(Git.Branch.make(name:)),
          exclude: [.make(remote: propose.target)],
          head: change.head
        ),
      ]
      case .replicate(let replicate): return try [
        .extraCommits(
          branches: protected.values
            .map(\.name)
            .map(Git.Branch.make(name:)),
          exclude: [.make(remote: replicate.target), .make(sha: replicate.fork)],
          head: change.head
        ),
        .forkInTarget(fork: replicate.fork, target: replicate.target),
        .forkNotInOriginal(fork: replicate.fork, original: replicate.original),
        .forkNotInSource(fork: replicate.fork, head: change.head),
        .forkParentNotInTarget(fork: replicate.fork, target: replicate.target),
      ]
      case .integrate(let integrate): return try [
        .extraCommits(
          branches: protected.values
            .map(\.name)
            .map(Git.Branch.make(name:)),
          exclude: [.make(remote: integrate.target), .make(sha: integrate.fork)],
          head: change.head
        ),
        .forkInTarget(fork: integrate.fork, target: integrate.target),
        .forkNotInOriginal(fork: integrate.fork, original: integrate.original),
        .forkNotInSource(fork: integrate.fork, head: change.head),
      ]
      case .duplicate(let duplicate): return [
        .notCherry(fork: duplicate.fork, head: change.head, target: duplicate.target),
        .forkInTarget(fork: duplicate.fork, target: duplicate.target),
        .forkNotInOriginal(fork: duplicate.fork, original: duplicate.original),
      ]
      case .propogate(let propogate): return [
        .notForward(fork: propogate.fork, head: change.head, target: propogate.target),
        .forkInTarget(fork: propogate.fork, target: propogate.target),
        .forkNotInOriginal(fork: propogate.fork, original: propogate.original),
        .forkNotInSource(fork: propogate.fork, head: change.head),
      ]}
    }
    public mutating func update(
      ctx: Context,
      merge: Json.GitlabMergeState,
      awards: [Json.GitlabAward],
      discussions: [Json.GitlabDiscussion]
    ) {
      if squash != merge.squash { add(problem: .squashCheck) }
      if merge.draft { add(problem: .draft) }
      if merge.blockingDiscussionsResolved.not {
        let discussions = discussions
          .compactMap({ $0.notes.first })
          .filter({ $0.resolvable && $0.resolved == false })
          .map(\.author.username)
          .reduce(into: [:], { $0[$1] = $0[$1].get(0) + 1 })
        add(problem: .discussions(discussions))
      }
      if case .propose(let propose) = change?.fusion {
        if let criteria = propose.proposition.title {
          var title = merge.title
          title = (try? title.dropPrefix("Draft: ")) ?? title
          title = (try? title.dropPrefix("WIP: ")) ?? title
          if criteria.isMet(title).not { add(problem: .badTitle) }
        }
        if let task = propose.proposition.task {
          let source = merge.sourceBranch.find(matches: task)
          let title = merge.title.find(matches: task)
          if Set(source).symmetricDifference(title).isEmpty.not {
            add(problem: .taskMismatch)
          }
        }
      }
      var holders = awards
        .filter({ $0.name == ctx.rules.hold })
        .reduce(into: Set(), { $0.insert($1.user.username) })
      if holders.intersection(ctx.bots).isEmpty { change?.addAward = ctx.rules.hold }
      holders = holders
        .subtracting(ctx.bots)
        .intersection(ctx.users.filter(\.value.active).keySet)
      if holders.isEmpty.not { add(problem: .holders(holders)) }
    }
    public func makeApprovesCheck() throws -> Fusion.ApprovesCheck? {
      guard let change = change, problems.get([]).contains(where: \.blocking).not
      else { return nil }
      switch change.fusion {
      case .propose(let propose): return .init(
        head: change.head,
        target: propose.target
      )
      case .replicate(let replicate): return .init(
        head: change.head,
        target: replicate.target,
        fork: replicate.fork
      )
      case .integrate(let integrate): return .init(
        head: change.head,
        target: integrate.target,
        fork: integrate.fork
      )
      case .duplicate(let duplicate): return .init(
        head: change.head,
        target: duplicate.target
      )
      case .propogate(let propogate): return .init(
        head: change.head,
        target: propogate.target
      )}
    }
    public mutating func update(
      ctx: Context,
      approvesCheck: Fusion.ApprovesCheck?
    ) {
      guard
        let change = change,
        let approvesCheck = approvesCheck,
        emergent.flatMapNil(verified) != change.head || isApproved.not || phase != .ready
      else { return }
      var changes = approvesCheck.changes
      for (sha, diff) in changes {
        if skip.contains(sha) || diff.isEmpty { changes[sha] = nil }
      }
      let childs = approvesCheck.childs
      let diff = approvesCheck.diff
      verified = nil
      emergent = emergent
        .flatMap({ childs[$0] })
        .flatMap({ $0.contains(where: { changes[$0] != nil }).else(change.head) })
      let sourceTeams = ctx.rules.sourceBranch
        .filter({ $0.value.isMet(change.fusion.source.name) })
        .keySet
      let targetTeams = ctx.rules.targetBranch
        .filter({ $0.value.isMet(change.fusion.target.name) })
        .keySet
      let diffTeams = change.fusion.diffApproval.then(change.ownage).get([:])
        .filter({ diff.contains(where: $0.value.isMet(_:)) })
        .keySet
      let authorshipTeams = change.fusion.authorshipApproval.then(ctx.rules.authorship).get([:])
        .filter({ $0.value.intersection(authors).isEmpty.not })
        .keySet
      let approvableTeams = diffTeams
        .union(sourceTeams)
        .union(targetTeams)
        .union(authorshipTeams)
      let randomTeams = change.fusion.randomApproval.then(ctx.rules.randoms).get([:])
        .filter({ $0.value.intersection(approvableTeams).isEmpty.not })
        .keySet
      let active = ctx.users.filter(\.value.active).keySet
        .subtracting(ctx.bots)
      authors = authors.subtracting(ctx.bots)
      if change.fusion.allowOrphaned.not, authors.intersection(active).isEmpty
      { add(problem: .orphaned(authors)) }
      legates = approvableTeams
        .compactMap({ ctx.rules.teams[$0] })
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .intersection(active)
        .intersection(legates)
      randoms = randomTeams
        .compactMap({ ctx.rules.teams[$0] })
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .intersection(active)
        .intersection(randoms)
      reviewers.keySet
        .subtracting(legates)
        .subtracting(randoms)
        .subtracting(authors)
        .forEach({ reviewers[$0] = nil })
      reviewers.values
        .filter({ childs[$0.commit] == nil })
        .forEach({ reviewers[$0.login] = nil })
      if let fork = change.fusion.autoApproveFork { authors
        .filter({ reviewers[$0] == nil })
        .forEach({ reviewers[$0] = .init(login: $0, commit: fork, resolution: .fragil) })
      }
      var brokenTeams = approvableTeams.subtracting(teams)
      teams = approvableTeams
      if change.fusion.target != target {
        brokenTeams.formUnion(targetTeams)
        target = change.fusion.target
      }
      brokenTeams
        .compactMap({ ctx.rules.teams[$0] })
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .forEach({ reviewers[$0]?.resolution = .obsolete })
      let fragilUtility = authorshipTeams
        .union(sourceTeams)
        .union(targetTeams)
        .compactMap({ ctx.rules.teams[$0] })
        .filter(\.advanceApproval.not)
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .intersection(legates)
      let fragilRandoms = randomTeams
        .compactMap({ ctx.rules.teams[$0] })
        .filter(\.advanceApproval.not)
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .intersection(randoms)
      let fragilUsers = authors
        .union(fragilUtility)
        .union(fragilRandoms)
        .union(reviewers.filter(\.value.resolution.fragil).keys)
      let fragilDiffApprovers = diffTeams
        .compactMap({ ctx.rules.teams[$0] })
        .filter(\.advanceApproval.not)
        .reduce(into: [:], { $0[$1.name] = $1.approvers })
      for reviewer in reviewers.values {
        guard let childs = childs[reviewer.commit] else {
          reviewers[reviewer.login] = nil
          continue
        }
        guard reviewer.resolution != .obsolete else { continue }
        let breakers = childs.compactMap({ changes[$0] })
        guard breakers.isEmpty.not else { continue }
        guard fragilUsers.contains(reviewer.login) else {
          reviewers[reviewer.login]?.resolution = .obsolete
          continue
        }
        for fragilUsers in breakers
          .reduce(into: Set(), { $0.formUnion($1) })
          .compactMap({ fragilDiffApprovers[$0] })
        {
          guard fragilUsers.contains(reviewer.login) else { continue }
          reviewers[reviewer.login]?.resolution = .obsolete
          break
        }
      }
      let unknownUsers = authors
        .union(reviewers.keys)
        .union(ctx.rules.ignore.keys)
        .union(ctx.rules.ignore.flatMap(\.value))
        .union(ctx.rules.authorship.flatMap(\.value))
        .union(ctx.rules.teams.flatMap(\.value.approvers))
        .union(ctx.rules.teams.flatMap(\.value.random))
        .subtracting(ctx.users.keys)
        .subtracting(ctx.bots)
      if unknownUsers.isEmpty.not { add(problem: .unknownUsers(unknownUsers)) }
      let unknownTeams = Set(ctx.rules.sanity.array)
        .union(change.ownage.keys)
        .union(ctx.rules.targetBranch.keys)
        .union(ctx.rules.sourceBranch.keys)
        .union(ctx.rules.authorship.keys)
        .union(ctx.rules.randoms.keys)
        .union(ctx.rules.randoms.flatMap(\.value))
        .filter({ ctx.rules.teams[$0] == nil })
      if unknownTeams.isEmpty.not { add(problem: .unknownTeams(unknownTeams)) }
      var confusedTeams = change.ownage.keySet
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
      var updateTeams = teams.compactMap({ ctx.rules.teams[$0] })
      updateTeams.indices.forEach({ updateTeams[$0].update(active: active) })
      var ignore = change.fusion.selfApproval.not.then(authors).get([])
      updateTeams.indices.forEach({ updateTeams[$0].update(exclude: ignore) })
      let unapprovable = updateTeams
        .filter(\.isUnapprovable)
        .reduce(into: Set(), { $0.insert($1.name) })
      if unapprovable.isEmpty.not { add(problem: .unapprovableTeams(unapprovable)) }
      if problems.get([]).contains(where: \.verifiable.not).not {
        var involved = authors
          .union(legates)
          .union(randoms)
        let necessary = updateTeams.reduce(into: Set(), { $0.formUnion($1.necessary) })
        legates.formUnion(necessary)
        involved.formUnion(necessary)
        updateTeams.indices.forEach({ updateTeams[$0].update(involved: involved) })
        legates.formUnion(selectUsers(
          ctx: ctx,
          teams: &updateTeams,
          involved: &involved,
          users: updateTeams.reduce(into: Set(), { $0.formUnion($1.approvers) })
        ))
        updateTeams = randomTeams.compactMap({ ctx.rules.teams[$0] })
        updateTeams.indices.forEach({ updateTeams[$0].update(active: active) })
        ignore = ctx.rules.ignore
          .filter({ $0.value.intersection(authors).isEmpty.not })
          .keySet
          .union(authors)
        updateTeams.indices.forEach({ updateTeams[$0].update(exclude: ignore) })
        updateTeams.indices.forEach({ updateTeams[$0].update(involved: involved) })
        randoms.formUnion(selectUsers(
          ctx: ctx,
          teams: &updateTeams,
          involved: &involved,
          users: updateTeams.reduce(into: Set(), { $0.formUnion($1.approvers) })
        ))
        verified = change.head
      }
      if problems.get([]).contains(where: \.blocking) {
        phase = .block
      } else if emergent == change.head {
        if problems.get([]).contains(where: \.skippable.not) {
          phase = .stuck
        } else {
          phase = .ready
        }
      } else if verified == change.head {
        if problems.get([]).isEmpty.not {
          phase = .stuck
        } else if isApproved {
          phase = .ready
        } else {
          phase = .amend
        }
      } else {
        phase = .stuck
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
    public static func make(
      review: String,
      yaml: Yaml.Review.Storage.State
    ) throws -> Self { try .init(
      review: review.getUInt(),
      source: .make(name: yaml.source),
      target: .make(name: yaml.target),
      original: yaml.original.map(Git.Branch.make(name:)),
      authors: Set(yaml.authors),
      phase: yaml.phase.map(Phase.make(yaml:)),
      skip: Set(yaml.skip.get([]).map(Git.Sha.make(value:))),
      teams: Set(yaml.teams.get([])),
      emergent: yaml.emergent.map(Git.Sha.make(value:)),
      verified: yaml.verified.map(Git.Sha.make(value:)),
      randoms: Set(yaml.randoms.get([])),
      legates: Set(yaml.legates.get([])),
      reviewers: yaml.reviewers.get([:])
        .map(Reviewer.make(login:yaml:))
        .reduce(into: [:], { $0[$1.login] = $1 })
    )}
  }
}
