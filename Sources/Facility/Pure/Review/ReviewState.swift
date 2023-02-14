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
    public var approves: [String: Approve] = [:]
    public var problems: [Problem]? = nil
    public var change: Change? = nil
    public var squash: Bool { original == nil }
    public mutating func approve(job: Json.GitlabJob, advance: Bool) throws -> Bool {
      let approve = try Approve(
        login: job.user.username,
        commit: .make(job: job),
        resolution: advance.then(.advance).get(.fragil)
      )
      guard
        verified == approve.commit,
        authors.union(legates).union(randoms).contains(approve.login),
        approve != approves[approve.login]
      else { return false }
      approves[approve.login] = approve
      return true
    }
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
    public mutating func shiftHead(to sha: Git.Sha) {
      if emergent != nil { emergent = sha }
      if verified != nil { verified = sha }
    }
    public mutating func shiftSkip(commit: Git.Sha, to sha: Git.Sha) {
      if skip.remove(commit) != nil { skip.insert(sha) }
    }
    public mutating func squashApproves(to sha: Git.Sha) {
      approves.keys.forEach({ approves[$0]?.commit = sha })
    }
    public func isUnapproved(user: String) -> Bool {
      guard let approve = approves[user] else { return true }
      return approve.resolution.approved.not
    }
    public var approvers: Set<String> { authors.union(legates).union(randoms) }
    var isApproved: Bool { approvers.contains(where: isUnapproved(user:)).not }
    public mutating func prepareChange(
      ctx: Context,
      merge: Json.GitlabMergeState
    ) throws -> Bool {
      let source = try Git.Branch.make(name: merge.sourceBranch)
      let target = try Git.Branch.make(name: merge.targetBranch)
      if target != self.target {
        emergent = nil
        verified = nil
      }
      if source != self.source { add(problem: .badSource(self.source.name)) }
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
          change = try .make(merge: merge, fusion: fusion)
          if source != fusion.source { add(problem: .targetMismatch(fusion.target)) }
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
          change = try .make(merge: merge, fusion: fusion)
        }
      }
      return change != nil
    }
    public mutating func checkSanity(
      ctx: Context,
      ownage: [String: Criteria],
      profile: Configuration.Profile
    ) -> Bool {
      guard let sanity = ctx.rules.sanity else { return true }
      guard
        let sanity = ownage[sanity],
        let codeOwnage = profile.codeOwnage,
        sanity.isMet(profile.location.path.value),
        sanity.isMet(codeOwnage.path.value)
      else {
        add(problem: .sanity(sanity))
        return false
      }
      return true
    }
    public mutating func makeGitCheck(
      branches: [Json.GitlabBranch]
    ) throws -> [Fusion.GitCheck] {
      guard let change = change else { return [] }
      let protected = branches
        .filter(\.protected)
        .reduce(into: Set(), { $0.insert($1.name) })
      if protected.contains(change.fusion.source.name) { add(problem: .sourceIsProtected) }
      if protected.contains(change.fusion.target.name).not { add(problem: .targetNotProtected) }
      guard problems.get([]).contains(where: \.blocking).not else { return [] }
      return try change.fusion.makeGitChecks(head: change.head, protected: protected)
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
          .reduce(into: [:], { $0[$1, default: 0] += 1 })
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
      if holders.intersection(ctx.bots).isEmpty { change?.addAward = true }
      holders = holders
        .subtracting(ctx.bots)
        .intersection(ctx.users.filter(\.value.active).keySet)
      if holders.isEmpty.not { add(problem: .holders(holders)) }
    }
    public var needApprovalCheck: Bool {
      guard
        let change = change,
        problems.get([]).contains(where: \.blocking).not,
        emergent != change.head,
        verified != change.head || isApproved.not
      else { return false }
      return true
    }
    public mutating func update(
      ctx: Context,
      childs: [Git.Sha: Set<Git.Sha>],
      diff: [String],
      diffs: [Git.Sha: [String]],
      ownage: [String: Criteria]
    ) {
      skip.formIntersection(childs.keys)
      var changes: [Git.Sha: Set<String>] = [:]
      guard let change = change else { return }
      let sourceTeams = ctx.rules.sourceBranch
        .filter({ $0.value.isMet(change.fusion.source.name) })
        .keySet
      let targetTeams = ctx.rules.targetBranch
        .filter({ $0.value.isMet(change.fusion.target.name) })
        .keySet
      let diffTeams = ownage
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
      approves.keySet
        .subtracting(legates)
        .subtracting(randoms)
        .subtracting(authors)
        .forEach({ approves[$0] = nil })
      approves.values
        .filter({ childs[$0.commit] == nil })
        .forEach({ approves[$0.login] = nil })
      var brokenTeams = approvableTeams.subtracting(teams)
      teams = approvableTeams
      if change.fusion.target != target {
        brokenTeams.formUnion(targetTeams)
        target = change.fusion.target
      }
      brokenTeams
        .compactMap({ ctx.rules.teams[$0] })
        .reduce(into: Set(), { $0.formUnion($1.approvers) })
        .forEach({ approves[$0]?.resolution = .obsolete })
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
        .union(approves.filter(\.value.resolution.fragil).keys)
      let fragilDiffApprovers = diffTeams
        .compactMap({ ctx.rules.teams[$0] })
        .filter(\.advanceApproval.not)
        .reduce(into: [:], { $0[$1.name] = $1.approvers })
      for (sha, diff) in diffs {
        guard diff.isEmpty.not else { continue }
        guard skip.contains(sha).not else {
          guard
            let sanity = ctx.rules.sanity,
            diffTeams.contains(sanity),
            let criteria = ownage[sanity],
            diff.contains(where: criteria.isMet(_:))
          else { continue }
          changes[sha] = [sanity]
          continue
        }
        var teams: Set<String> = []
        for team in diffTeams {
          guard
            let criteria = ownage[team],
            diff.contains(where: criteria.isMet(_:))
          else { continue }
          teams.insert(team)
        }
        changes[sha] = teams
      }
      for approve in approves.values {
        guard let childs = childs[approve.commit] else {
          approves[approve.login] = nil
          continue
        }
        guard approve.resolution != .obsolete else { continue }
        guard childs.contains(where: { changes[$0] != nil }).not else { continue }
        guard fragilUsers.contains(approve.login) else {
          approves[approve.login]?.resolution = .obsolete
          continue
        }
        for fragilUsers in childs
          .compactMap({ changes[$0] })
          .reduce(into: Set(), { $0.formUnion($1) })
          .compactMap({ fragilDiffApprovers[$0] })
          .reduce(into: Set(), { $0.formUnion($1) })
        {
          guard fragilUsers.contains(approve.login) else { continue }
          approves[approve.login]?.resolution = .obsolete
          break
        }
      }
      verified = nil
      emergent = emergent
        .flatMap({ childs[$0] })
        .flatMap({ $0.contains(where: { changes[$0] != nil }).else(change.head) })
      guard emergent == nil else { return }
      if change.fusion.allowOrphaned.not, diff.isEmpty.not, authors.intersection(active).isEmpty
      { add(problem: .orphaned(authors)) }
      let unknownUsers = authors
        .union(approves.keys)
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
      var updateTeams = teams.compactMap({ ctx.rules.teams[$0] })
      updateTeams.indices.forEach({ updateTeams[$0].update(active: active) })
      var ignore = change.fusion.selfApproval.not.then(authors).get([])
      updateTeams.indices.forEach({ updateTeams[$0].update(exclude: ignore) })
      let unapprovable = updateTeams
        .filter(\.isUnapprovable)
        .reduce(into: Set(), { $0.insert($1.name) })
      if unapprovable.isEmpty.not { add(problem: .unapprovableTeams(unapprovable)) }
      guard problems.get([]).contains(where: \.verifiable.not).not else { return }
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
    public var canRebase: Bool {
      guard let change = change, change.fusion.proposition, emergent == nil else { return false }
      return verified == change.head
    }
    public mutating func updatePhase() {
      guard let change = change else {
        phase = .block
        return
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
    public func reportChanges(
      ctx: Context,
      old: State?,
      foremost: Set<UInt>,
      enqueued: Set<UInt>,
      dequeued: Set<UInt>
    ) {
      var shift: [Report.ReviewEvent.Reason] = []
      if old == nil { shift.append(.created) }
      if emergent != nil, old?.emergent == nil { shift.append(.emergent) }
      if emergent == nil, old?.emergent != nil { shift.append(.tranquil) }
      if phase == .block, old?.phase != .block { shift.append(.block) }
      if phase == .stuck, old?.phase != .stuck { shift.append(.stuck) }
      if phase == .amend, old?.phase != .block { shift.append(.amend) }
      if phase == .ready, old?.phase != .ready { shift.append(.ready) }
      if foremost.contains(review) { shift.append(.foremost) }
      if enqueued.contains(review) { shift.append(.enqueued) }
      if dequeued.contains(review) { shift.append(.dequeued) }
      guard let change = change else {
        return shift.forEach({ ctx.cfg.reportReviewEvent(
          state: self, update: nil, reason: $0, merge: nil
        )})
      }
      var update = Report.ReviewUpdated(
        authors: authors.intersection(ctx.approvers).sortedNonEmpty,
        teams: teams.sortedNonEmpty,
        watchers: ctx.watchers(state: self).sortedNonEmpty
      )
      update.change(state: self)
      var approvers: [String: Approver] = [:]
      for approve in self.approvers {
        if let approve = approves[approve] {
          approvers[approve.login] = .present(reviewer: approve)
        } else {
          approvers[approve] = .init(login: approve, miss: true)
        }
      }
      if self.problems.get([]).isEmpty.not { update.problems = .init() }
      for problem in self.problems.get([]) {
        update.problems?.register(problem: problem)
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
      if approvers.isEmpty.not {
        update.approvers = approvers.keys.sorted().compactMap({ approvers[$0] })
      }
      shift.forEach({ ctx.cfg.reportReviewEvent(
        state: self,
        update: update,
        reason: $0,
        merge: change.merge
      )})
      ctx.cfg.reportReviewUpdated(state: self, merge: change.merge, report: update)
      for approve in approves.values.filter(\.resolution.approved.not) {
        if let old = ctx.originalStorage.states[review]?.approves[approve.login] {
          guard old.resolution.approved.not else { continue }
          ctx.cfg.reportReviewApprove(
            user: old.login,
            merge: change.merge,
            approve: .init(diff: old.commit.value, reason: .change)
          )
        } else {
          ctx.cfg.reportReviewApprove(
            user: approve.login,
            merge: change.merge,
            approve: .init(reason: .create)
          )
        }
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
      merge: Json.GitlabMergeState,
      bots: Set<String>
    ) throws -> Self { try .init(
      review: merge.iid,
      source: .make(name: merge.sourceBranch),
      target: .make(name: merge.targetBranch),
      authors: Set([merge.author.username]).subtracting(bots)
    )}
    public static func make(
      review: String,
      yaml: Yaml.Review.Storage.State
    ) throws -> Self { try .init(
      review: review.getUInt(),
      source: .make(name: yaml.source),
      target: .make(name: yaml.target),
      original: yaml.fusion.map(Git.Branch.make(name:)),
      authors: Set(yaml.authors.get([])),
      phase: yaml.phase.map(Phase.make(yaml:)),
      skip: Set(yaml.skip.get([]).map(Git.Sha.make(value:))),
      teams: Set(yaml.teams.get([])),
      emergent: yaml.emergent.map(Git.Sha.make(value:)),
      verified: yaml.verified.map(Git.Sha.make(value:)),
      randoms: Set(yaml.randoms.get([])),
      legates: Set(yaml.legates.get([])),
      approves: yaml.approves.get([:]).map(Approve.make(login:yaml:)).indexed(\.login)
    )}
    public struct Resolve: Query {
      public var cfg: Configuration
      public var merge: Json.GitlabMergeState
      public static func make(
        cfg: Configuration,
        merge: Json.GitlabMergeState
      ) -> Self { .init(
        cfg: cfg,
        merge: merge
      )}
      public typealias Reply = State
    }
  }
}
