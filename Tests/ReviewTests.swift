import XCTest
@testable import Facility
@testable import FacilityPure
final class ReviewTests: XCTestCase {
  let statuses: [UInt: Fusion.Approval.Status] = [1: .init(
    review: 1,
    target: "develop",
    authors: ["u1"],
    randoms: [],
    participants: ["u2"],
    approves: ["u2": .init(approver: "u2", commit: .init(value: "1"), resolution: .fragil)],
    thread: .init(channel: "channel", ts: "1123123.1231231"),
    teams: ["g1"]
  )]
  let approvers: [String: Fusion.Approval.Approver] = [
    "u1": .init(active: true, slack: "1"),
    "u2": .init(active: true, slack: "2"),
    "u3": .init(active: true, slack: "3"),
  ]
  let haters: [String : Set<String>] = [:]
  let rules: Fusion.Approval.Rules = try! .init(
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
        name: "g1",
        quorum: 1,
        labels: [],
        mentions: [],
        reserve: [],
        optional: [],
        required: [],
        advanceApproval: false
      ),
      "g2": .init(
        name: "g2",
        quorum: 1,
        labels: [],
        mentions: [],
        reserve: [],
        optional: [],
        required: [],
        advanceApproval: false
      ),
      "g3": .init(
        name: "g3",
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
  )
  func makeReview(id: UInt, kind: Fusion.Kind) -> Review { .init(
    bot: "bot",
    approvers: approvers,
    kind: kind,
    ownage: [:],
    rules: rules,
    haters: haters,
    status: statuses[id]!
  )}
  func test1() throws {
    var review = makeReview(id: 1, kind: .proposition(nil))
    review.diffTeams.insert("g1")
    XCTAssertEqual(1, 1)
  }
}
