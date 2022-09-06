import Foundation
import Facility
public struct ReviewQueue {
  public private(set) var queue: [String: [UInt]]
  public private(set) var isChanged: Bool = false
  public private(set) var notifiables: Set<UInt> = []
  public var yaml: String {
    var result: String = ""
    for target in queue.keys.sorted() {
      guard let reviews = queue[target], !reviews.isEmpty else { continue }
      result += "'\(target)':\n"
      for review in reviews { result += "- \(review)\n" }
    }
    return result.isEmpty.else(result).get("{}\n")
  }
  public mutating func enqueue(review: UInt, target: String?) -> Bool {
    var result = false
    for (key, value) in queue {
      if key == target {
        guard !value.contains(where: { $0 == review }) else {
          result = value.first == review
          continue
        }
        queue[key] = value + [review]
        isChanged = true
        if queue[key]?.first == review { notifiables.insert(review) }
      } else {
        let targets = value.filter { $0 != review }
        guard value.count != targets.count else { continue }
        queue[key] = targets.isEmpty.else(targets)
        isChanged = true
        if let first = targets.first, first != value.first { notifiables.insert(first) }
      }
    }
    if let target = target, queue[target] == nil {
      queue[target] = [review]
      isChanged = true
      notifiables.insert(review)
    }
    return result
  }
  public static func make(queue: [String: [UInt]]) -> Self { .init(queue: queue) }
  public struct Resolve: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = ReviewQueue
  }
  public struct Persist: Query {
    public var cfg: Configuration
    public var pushUrl: String
    public var reviewQueue: ReviewQueue
    public var review: Json.GitlabReviewState
    public var queued: Bool
    public init(
      cfg: Configuration,
      pushUrl: String,
      reviewQueue: ReviewQueue,
      review: Json.GitlabReviewState,
      queued: Bool
    ) {
      self.cfg = cfg
      self.pushUrl = pushUrl
      self.reviewQueue = reviewQueue
      self.review = review
      self.queued = queued
    }
    public typealias Reply = Void
  }
}
