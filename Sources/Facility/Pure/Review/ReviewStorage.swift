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
    public mutating func delete(merge: Json.GitlabMergeState) {
      states[merge.iid] = nil
      queues = queues.reduce(into: [:], { $0[$1.key] = $1.value.filter({ $0 != merge.iid }) })
    }
  }
}
