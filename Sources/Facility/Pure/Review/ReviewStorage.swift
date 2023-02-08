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
          if let users = state.reviewers.keys.sortedNonEmpty?.compactMap({ state.reviewers[$0] }) {
            result += "    approves:\n"
            result += users
              .map({ "      '\($0.login)': {\($0.resolution.rawValue): '\($0.commit.value)'}\n" })
              .joined()
          }


//          public var reviewers: [String: Reviewer]?


//          public var authors: Set<String>
//          public var phase: Phase? = nil
//          public var skip: Set<Git.Sha> = []
//          public var teams: Set<String> = []
//          public var emergent: Git.Sha? = nil
//          public var verified: Git.Sha? = nil
//          public var randoms: Set<String> = []
//          public var legates: Set<String> = []
          //          public var reviewers: [String: Reviewer] = [:]
          //          public var approvers: [String: Reviewer] = [:]
//
//
//          let iids = queues[queue].get([]).map({ "\($0)" }).joined(separator: ",")
//          result += "  '\(queue)': [\(iids)]"
        }

      }
      return result
//      for status in statuses.values.sorted(by: { $0.review < $1.review }) {
//        result += "'\(status.review)':\n"
//        result += "  target: '\(status.target)'\n"
//        let authors = status.authors
//          .sorted()
//          .map({ "'\($0)'" })
//          .joined(separator: ",")
//        result += "  authors: [\(authors)]\n"
//        result += "  state: \(status.state.rawValue)\n"
//        let skip = status.skip.map(\.value).sorted().map({ "'\($0)'" }).joined(separator: ",")
//        if skip.isEmpty.not { result += "  skip: [\(skip)]\n" }
//        let teams = status.teams.sorted().map({ "'\($0)'" }).joined(separator: ",")
//        if teams.isEmpty.not { result += "  teams: [\(teams)]\n" }
//        if let verified = status.verified?.value { result += "  verified: '\(verified)'\n" }
//        if let emergent = status.emergent?.value { result += "  emergent: '\(emergent)'\n" }
//        let legates = status.legates.sorted().map { "'\($0)'" }.joined(separator: ",")
//        if legates.isEmpty.not { result += "  legates: [\(legates)]\n" }
//        let randoms = status.randoms.sorted().map { "'\($0)'" }.joined(separator: ",")
//        if randoms.isEmpty.not { result += "  randoms: [\(randoms)]\n" }
//        if let replicate = status.replicate { result += "  replicate: '\(replicate.name)'\n" }
//        if let integrate = status.integrate { result += "  integrate: '\(integrate.name)'\n" }
//        let approves = status.approves.keys
//          .sorted()
//          .compactMap({ status.approves[$0] })
//          .map({ "    '\($0.approver)': {\($0.resolution.rawValue): '\($0.commit.value)'}\n" })
//        if approves.isEmpty.not { result += "  approves:\n" + approves.joined() }
//      }
//      return result.isEmpty.then("{}\n").get(result)
    }
  }
}
