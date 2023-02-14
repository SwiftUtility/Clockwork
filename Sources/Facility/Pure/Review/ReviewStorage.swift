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
      states: yaml.states.map(State.make(review:yaml:)).indexed(\.review)
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
    var serialized: String {
      var result = ""
      let queues = queues.filter(\.value.isEmpty.not)
      if queues.isEmpty { result += "queues: {}\n" } else {
        result += "queues:\n"
        for queue in queues.keys.sorted() {
          let iids = queues[queue].get([]).map({ "\($0)" }).joined(separator: ",")
          result += "  '\(queue)': [\(iids)]"
        }
      }
      if states.isEmpty { result += "states: {}\n" } else {
        result += "states:\n"
        for state in states.keys.sorted().compactMap({ states[$0] }) {
          result += "  '\(state.review)':\n"
          result += "    source: '\(state.source.name)'\n"
          result += "    target: '\(state.target.name)'\n"
          if let original = state.original {
            result += "    fusion: '\(original.name)'\n"
          }
          if let authors = state.authors.sortedNonEmpty {
            result += "    authors: ['\(authors.joined(separator: "','"))']\n"
          }
          if let phase = state.phase {
            result += "    phase: \(phase.rawValue)\n"
          }
          if let skip = state.skip.map(\.value).sortedNonEmpty {
            result += "    skip:\n"
            result += skip.map({ "    - '\($0)'\n" }).joined()
          }
          if let teams = state.teams.sortedNonEmpty {
            result += "    teams: ['\(teams.joined(separator: "','"))']\n"
          }
          if let emergent = state.emergent {
            result += "    emergent: '\(emergent)'\n"
          }
          if let verified = state.verified {
            result += "    verified: '\(verified.value)'\n"
          }
          if let randoms = state.randoms.sortedNonEmpty {
            result += "    randoms: ['\(randoms.joined(separator: "','"))']\n"
          }
          if let legates = state.legates.sortedNonEmpty {
            result += "    legates: ['\(legates.joined(separator: "','"))']\n"
          }
          if let users = state.approves.keys.sortedNonEmpty?.compactMap({ state.approves[$0] }) {
            result += "    approves:\n"
            result += users
              .map({ "      '\($0.login)': {\($0.resolution.rawValue): '\($0.commit.value)'}\n" })
              .joined()
          }
        }
      }
      return result
    }
  }
}
