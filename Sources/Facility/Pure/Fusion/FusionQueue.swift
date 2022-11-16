import Foundation
import Facility
extension Fusion {
  public struct Queue {
    public internal(set) var queue: [String: [UInt]]
    public var yaml: String {
      guard queue.isEmpty.not else { return "{}\n" }
      return queue
        .map({ "'\($0.key)': [\($0.value.map(String.init(_:)).joined(separator: ", "))]\n" })
        .sorted()
        .joined()
    }
    public mutating func enqueue(review: UInt, target: String?) -> Set<UInt> {
      var result: Set<UInt> = []
      for (key, value) in queue {
        if key == target {
          guard !value.contains(where: { $0 == review }) else { continue }
          queue[key] = value + [review]
        } else {
          let targets = value.filter { $0 != review }
          guard value.count != targets.count else { continue }
          queue[key] = targets.isEmpty.else(targets)
          if let first = targets.first, first != value.first { result.insert(first) }
        }
      }
      if let target = target, queue[target] == nil { queue[target] = [review] }
      return result
    }
    public func isFirst(review: UInt, target: String) -> Bool { queue[target]?.first == review }
    public static func make(queue: [String: [UInt]]) -> Self { .init(queue: queue) }
    public struct Resolve: Query {
      public var cfg: Configuration
      public var fusion: Fusion
      public init(
        cfg: Configuration,
        fusion: Fusion
      ) {
        self.cfg = cfg
        self.fusion = fusion
      }
      public typealias Reply = Fusion.Queue
    }
    public struct Persist: Query {
      public var cfg: Configuration
      public var pushUrl: String
      public var fusion: Fusion
      public var reviewQueue: Fusion.Queue
      public var review: Json.GitlabReviewState
      public var queued: Bool
      public init(
        cfg: Configuration,
        pushUrl: String,
        fusion: Fusion,
        reviewQueue: Fusion.Queue,
        review: Json.GitlabReviewState,
        queued: Bool
      ) {
        self.cfg = cfg
        self.pushUrl = pushUrl
        self.fusion = fusion
        self.reviewQueue = reviewQueue
        self.review = review
        self.queued = queued
      }
      public typealias Reply = Void
    }
  }
}
