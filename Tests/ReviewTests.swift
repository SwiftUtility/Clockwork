import XCTest
@testable import Facility
@testable import FacilityPure
final class ReviewTests: XCTestCase {
  let statuses: [UInt: Fusion.Approval.Status] = [
    .init(
      review: 1,
      target: "develop",
      authors: ["u1"],
      randoms: [],
      participants: ["u2"],
      approves: ["u2": .init(approver: "u2", commit: .init(value: "1"), resolution: .fragil)],
      thread: .init(channel: "channel", ts: "1123123.1231231"),
      teams: ["g1"],
      emergent: false
    ),
  ].reduce(into: [:], { $0[$1.review] = $1})
  let approvers: [String: Fusion.Approval.Approver] = [
    .init(login: "u1", active: true, slack: "1"),
    .init(login: "u2", active: true, slack: "2"),
    .init(login: "u3", active: true, slack: "3"),
    .init(login: "u4", active: true, slack: "3"),
    .init(login: "u5", active: true, slack: "3"),
    .init(login: "u6", active: true, slack: "3"),
    .init(login: "u7", active: true, slack: "3"),
  ].reduce(into: [:], { $0[$1.login] = $1})
  let haters: [String : Set<String>] = [:]
  let ownage = try! [
    "o1": Criteria.init(includes: ["o1"]),
    "o2": Criteria.init(includes: ["o2"]),
  ]
  let rules: Fusion.Approval.Rules = try! .init(
    sanity: "g1",
    randoms: .init(
      quorum: 2,
      baseWeight: 500,
      weights: [:],
      advanceApproval: true
    ),
    teams: [
      .init(
        name: "o1",
        quorum: 1,
        labels: [],
        mentions: [],
        reserve: [],
        optional: ["u4"],
        required: ["u1"],
        advanceApproval: false
      ),
      .init(
        name: "o2",
        quorum: 2,
        labels: [],
        mentions: [],
        reserve: [],
        optional: ["u5", "u4"],
        required: ["u2"],
        advanceApproval: false
      ),
      .init(
        name: "a1",
        quorum: 1,
        labels: [],
        mentions: [],
        reserve: [],
        optional: [],
        required: ["u3"],
        advanceApproval: false
      ),
      .init(
        name: "t1",
        quorum: 1,
        labels: [],
        mentions: [],
        reserve: [],
        optional: [],
        required: ["u3"],
        advanceApproval: false
      ),
    ].reduce(into: [:], { $0[$1.name] = $1}),
    authorship: [
      "a1": ["u1", "u2"],
    ],
    sourceBranch: [:],
    targetBranch: [
      "t1": .init(includes: ["develop"]),
    ]
  )
  func makeReview(id: UInt, kind: Fusion.Kind) -> Review { .init(
    bot: "bot",
    approvers: approvers,
    kind: kind,
    ownage: ownage,
    rules: rules,
    haters: haters,
    unknownUsers: [],
    unknownTeams: [],
    status: statuses[id]!
  )}
  func test1() throws {
    var review = makeReview(id: 1, kind: .proposition(nil))
    review.prepareVerification(source: "task", target: review.status.target)
    review.prepareVerification(diff: ["o1", "o2"])
    let approval = review.performVerification(sha: .init(value: "0"))
    XCTAssert(approval.blockers.contains("u1"))
  }
}
