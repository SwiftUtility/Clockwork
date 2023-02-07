import Foundation
import Facility
extension Review {
  public struct Storage {
    public var asset: Configuration.Asset
    public internal(set) var queues: [String: [UInt]]
    public internal(set) var states: [UInt: State]
    public static func make(
      review: Review,
      yaml: Yaml.Review.Storage
    ) throws -> Self { try .init(
      asset: review.storage,
      queues: yaml.queues,
      states: yaml.states
        .map(State.make(review:yaml:))
        .reduce(into: [:], { $0[$1.review] = $1 })
    )}
    mutating func delete(review: UInt) -> State? {
      let result = states[review]
      states[review] = nil
      dequeue(review: review)
      return result
    }
    mutating func dequeue(review: UInt) {
      queues = queues.reduce(into: [:], { $0[$1.key] = $1.value.filter({ $0 != review }) })
    }
    mutating func enqueue(state: State) {
      for (target, reviews) in queues {
        if target == state.target.name {
          if reviews.contains(state.review).not { queues[target] = reviews + [state.review] }
        } else {
          queues[target] = reviews.filter({ $0 != state.review })
        }
      }
    }
  }
}
