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
          cfg.reportReviewEvent(state: state, update: nil, reason: .closed, merge: merge)
        }
        return nil
      }
      guard merge.isMerged.not else { 
        if let state = storage.delete(review: merge.iid) {
          cfg.reportReviewEvent(state: state, update: nil, reason: .merged, merge: merge)
        }
        return nil
      }
      return try storage.states[merge.iid].get(.init(
        review: merge.iid,
        source: .make(name: merge.sourceBranch),
        target: .make(name: merge.targetBranch),
        authors: [merge.author.username]
      ))
    }
    public func remind(review: UInt, user: String) -> Report.ReviewApprove {
      .init(diff: storage.states[review]?.approves[user]?.commit.value, reason: .remind)
    }
    public mutating func merge(merge: Json.GitlabMergeState) {
      if let state = storage.delete(review: merge.iid) {
        cfg.reportReviewEvent(state: state, update: nil, reason: .merged, merge: merge)
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
      storage.queues.flatMap(\.value).contains(merge.iid)
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
    func watchers(state: State) -> Set<String> {
      var result: Set<String> = []
      for user in approvers.compactMap({ users[$0] }) {
        if user.watchTeams.isDisjoint(with: state.teams).not { result.insert(user.login) }
        if user.watchAuthors.isDisjoint(with: state.authors).not { result.insert(user.login) }
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
