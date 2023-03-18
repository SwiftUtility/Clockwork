import Foundation
import Facility
import FacilityPure
public struct Contract: Codable {
  var job: UInt
  var chunks: UInt
  var version: String
  var subject: String
  func unpack<Performer: ContractPerformer>(
    _ performer: Performer.Type,
    ctx: ContextCommon
  ) throws -> ContractPerformer? {
    guard subject == performer.subject else { return nil }
    let base = try (0 ..< chunks)
      .map({ try ctx.sh.get(env: "\(Self.contract)_\($0)") })
      .joined()
    guard let data = Data(base64Encoded: base)
    else { throw Thrown("Contract payload not base64 encoded") }
    return try ctx.sh.rawDecoder.decode(performer, from: data)
  }
  func performer(ctx: ContextCommon) throws -> ContractPerformer {
    if let result = try unpack(UseCase.ConnectClean.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ConnectSignal.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowChangeAccessory.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowChangeNext.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowCreateAccessory.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowCreateDeploy.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowCreateStage.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowDeleteBranch.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowDeleteTag.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowReserveBuild.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowStartHotfix.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FlowStartRelease.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.FusionStart.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewAccept.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewApprove.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewDequeue.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewEnqueue.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewLabels.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewList.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewOwnage.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewPatch.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewRebase.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewRemind.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewSkip.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.ReviewUpdate.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.UserActivity.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.UserRegister.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.UserWatchAuthors.self, ctx: ctx) { return result }
    if let result = try unpack(UseCase.UserWatchTeams.self, ctx: ctx) { return result }
    throw Thrown("Unknown contract: \(subject)")
  }
  static var chunkSize: Int { 2047 }
  static var contract: String { "CLOCKWORK_CONTRACT" }
  static func pack<Payload: ContractPerformer>(
    ctx: ContextGitlab,
    payload: Payload
  ) throws -> [Variable] {
    let payload = try ctx.sh.rawEncoder.encode(payload).base64EncodedString()
    var count: UInt = 0
    var startIndex = payload.startIndex
    var result: [Variable] = []
    while startIndex < payload.endIndex {
      let endIndex = payload
        .index(startIndex, offsetBy: chunkSize, limitedBy: payload.endIndex)
        .get(payload.endIndex)
      result.append(.make(
        key: "\(contract)_\(count)",
        value: String(payload[startIndex..<endIndex])
      ))
      count += 1
      startIndex = endIndex
    }
    try result.append(.init(
      key: contract,
      value: ctx.sh.rawEncoder
        .encode(Self(
          job: ctx.gitlab.current.id,
          chunks: count,
          version: ctx.repo.profile.version,
          subject: Payload.subject
        ))
        .base64EncodedString()
    ))
    return result
  }
  static func unpack(
    ctx: ContextCommon
  ) throws -> Self {
    guard let data = try Data(base64Encoded: ctx.sh.get(env: contract))
    else { throw Thrown("Contract not base64 encoded") }
    return try ctx.sh.rawDecoder.decode(Self.self, from: data)
  }
  struct Variable: Encodable {
    var key: String
    var value: String
    static func make(key: String, value: String) -> Self {
      .init(key: key, value: value)
    }
  }
  struct Payload: Encodable {
    var ref: String
    var variables: [Variable]
    static func make(ref: String, variables: [Variable]) -> Self {
      .init(ref: ref, variables: variables)
    }
  }
}
