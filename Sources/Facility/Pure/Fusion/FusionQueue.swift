import Foundation
import Facility
extension Fusion {
  public struct Queue {
    public var asset: Configuration.Asset
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
    public func isFirst(review: Json.GitlabReviewState) -> Bool {
      queue[review.targetBranch]?.first == review.iid
    }
    public func isQueued(review: Json.GitlabReviewState) -> Bool {
      queue[review.targetBranch].get([]).contains(review.iid)
    }
    public static func make(
      fusion: Fusion,
      queue: [String: [UInt]]
    ) -> Self { .init(
      asset: fusion.queue,
      queue: queue
    )}
  }
}
