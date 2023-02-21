import Foundation
import Facility
extension Review {
  public struct Context {
    public var cfg: Configuration
    public var bots: Set<String>
    public var approvers: Set<String>
    public var users: [String: Gitlab.Storage.User]
    public var review: Review
    public var rules: Review.Rules
    public var storage: Review.Storage
    public var originalStorage: Review.Storage
    public var trigger: Set<UInt> = []
    public var award: Set<UInt> = []
    public var message: Generate.CreateReviewStorageCommitMessage = .init()
    public mutating func makeState(merge: Json.GitlabMergeState) throws -> State? {
      guard merge.isClosed.not else {
        if let state = storage.delete(review: merge.iid) {
          cfg.reportReviewEvent(state: state, merge: merge, reason: .closed)
        }
        return nil
      }
      guard merge.isMerged.not else { 
        if let state = storage.delete(review: merge.iid) {
          cfg.reportReviewEvent(state: state, merge: merge, reason: .merged)
        }
        return nil
      }
      var state = try storage.states[merge.iid].get(.make(merge: merge, bots: bots))
      state.merge = merge
      if merge.targetBranch != state.target.name {
        state.approves.keys.forEach({ state.approves[$0]?.resolution = .obsolete })
        state.emergent = nil
        state.verified = nil
        state.target = try .make(name: merge.targetBranch)
      }
      storage.states[merge.iid] = state
      return state
    }
    public mutating func merge(merge: Json.GitlabMergeState) {
      if let state = storage.delete(review: merge.iid) {
        cfg.reportReviewEvent(state: state, merge: merge, reason: .merged)
      }
    }
    public mutating func dequeue(merge: Json.GitlabMergeState) {
      storage.dequeue(review: merge.iid)
    }
    public mutating func update(state: State) {
      storage.states[state.review] = state
      if state.phase == .ready {
        storage.enqueue(state: state)
      } else {
        storage.dequeue(review: state.review)
      }
    }
    public func isFirst(merge: Json.GitlabMergeState) -> Bool {
      storage.queues.compactMap(\.value.first).contains(merge.iid)
    }
    public func isQueued(merge: Json.GitlabMergeState) -> Bool {
      storage.queues[merge.targetBranch].get([]).contains(merge.iid)
    }
    public static func make(
      cfg: Configuration,
      review: Review,
      rules: Review.Rules,
      storage: Review.Storage
    ) throws -> Self {
      let gitlab = try cfg.gitlab.get()
      let bots = try gitlab.storage.bots.union([gitlab.rest.get().user.username])
      let users = gitlab.storage.users
      return .init(
        cfg: cfg,
        bots: bots,
        approvers: Set(users.values.filter(\.active).map(\.login)).subtracting(bots),
        users: users,
        review: review,
        rules: rules,
        storage: storage,
        originalStorage: storage
      )
    }
    func watchers(state: State, old: State?) -> Set<String> {
      var result: Set<String> = []
      let teams = state.teams.subtracting(old.map(\.teams).get([]))
      let authors = state.authors.subtracting(old.map(\.authors).get([]))
      guard teams.isEmpty.not || authors.isEmpty.not else { return [] }
      for user in approvers.compactMap({ users[$0] }) {
        if user.watchTeams.isDisjoint(with: teams).not { result.insert(user.login) }
        if user.watchAuthors.isDisjoint(with: authors).not { result.insert(user.login) }
      }
      return result
    }
    public mutating func serialize(skip: UInt?) -> String {
      let newFirst = Set(storage.queues.compactMap(\.value.first))
      let oldFirst = Set(originalStorage.queues.compactMap(\.value.first))
      let newQueue = Set(storage.queues.flatMap(\.value))
      let oldQueue = Set(originalStorage.queues.flatMap(\.value))
      let newPresent = storage.states.keySet
      let oldPresent = originalStorage.states.keySet
      let foremost = newFirst.subtracting(oldFirst)
      let enqueued = newQueue.subtracting(oldQueue)
      let dequeued = oldQueue.subtracting(newQueue)
      trigger.formUnion(foremost.subtracting(skip.array))
      storage.states.values
        .compactMap({ $0.change })
        .filter(\.addAward)
        .forEach({ award.insert($0.merge.iid) })
      let update = newPresent
        .intersection(oldPresent)
        .filter({ storage.states[$0]?.change != nil })
        .union(newPresent.subtracting(oldPresent))
        .subtracting(enqueued)
      message = .init(
        update: update.sortedNonEmpty,
        delete: oldPresent.subtracting(newPresent).sortedNonEmpty,
        enqueue: enqueued.sortedNonEmpty,
        dequeue: dequeued.subtracting(update).intersection(newPresent).sortedNonEmpty
      )
      for state in storage.states.values { state.reportChanges(
        ctx: self,
        old: originalStorage.states[state.review],
        foremost: foremost,
        enqueued: enqueued,
        dequeued: dequeued
      )}
      return storage.serialized
    }
  }
}
