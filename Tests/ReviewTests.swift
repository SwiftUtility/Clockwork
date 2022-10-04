import XCTest
@testable import Facility
@testable import FacilityPure
final class ReviewTests: XCTestCase {
  static let statuses: [UInt: Fusion.Approval.Status] = [1: .init(
    target: "develop",
    authors: ["one"],
    randoms: [],
    participants: [],
    approves: [:],
    thread: .init(channel: "channel", ts: "1123123.1231231")
  )]
  let review = try! Review(
    bot: "bot",
    approvers: [
      "u1": .init(active: true, slack: "1", name: "u1"),
      "u2": .init(active: true, slack: "2", name: "u2"),
      "u3": .init(active: true, slack: "3", name: "u3"),
    ],
    kind: .proposition(nil),
    ownage: [:],
    rules: .init(
      sanity: "g1",
      emergency: "emergency",
      randoms: .init(
        quorum: 4,
        baseWeight: 500,
        weights: [:],
        advanceApproval: true
      ),
      teams: [
        "g1": .init(
          quorum: 1,
          labels: [],
          mentions: [],
          reserve: [],
          optional: [],
          required: [],
          advanceApproval: false
        ),
        "g2": .init(
          quorum: 1,
          labels: [],
          mentions: [],
          reserve: [],
          optional: [],
          required: [],
          advanceApproval: false
        ),
        "g3": .init(
          quorum: 1,
          labels: [],
          mentions: [],
          reserve: [],
          optional: [],
          required: [],
          advanceApproval: false
        ),
      ],
      authorship: [
        "g2": ["u1", "u2"],
      ],
      sourceBranch: [:],
      targetBranch: [
        "g3": .init(includes: ["develop"]),
      ]
    ),
    haters: [:],
    status: statuses[1]!
  )
}
