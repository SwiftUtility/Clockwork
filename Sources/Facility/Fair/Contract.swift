import Foundation
import Facility
import FacilityPure
public struct Contract: Codable {
  public var job: UInt
  public var chunks: UInt
  public var version: String
  public var subject: String
  public func unpack<Payload: ContractPerformer>(
    payload: Payload.Type,
    env: [String: String],
    decoder: JSONDecoder
  ) throws -> Payload? {
    guard subject == Payload.subject else { return nil }
    let base = try (0 ..< chunks)
      .map({ try "\(Self.contract)_\($0)".get(env: env) })
      .joined()
    guard let data = Data(base64Encoded: base)
    else { throw Thrown("Contract payload not base64 encoded") }
    return try decoder.decode(Payload.self, from: data)
  }
  public static var chunkSize: Int { 2047 }
  public static var contract: String { "CLOCKWORK_CONTRACT" }
  public static var payloads: [ContractPerformer.Type] {[
    UseCase.ConnectClean.self,
    UseCase.ConnectSignal.self,
    UseCase.FlowChangeAccessory.self,
    UseCase.FlowChangeNext.self,
    UseCase.FlowCreateAccessory.self,
    UseCase.FlowCreateDeploy.self,
    UseCase.FlowCreateStage.self,
    UseCase.FlowDeleteBranch.self,
    UseCase.FlowDeleteTag.self,
    UseCase.FlowReserveBuild.self,
    UseCase.FlowStartHotfix.self,
    UseCase.FlowStartRelease.self,
    UseCase.FusionStart.self,
    UseCase.ReviewAccept.self,
    UseCase.ReviewApprove.self,
    UseCase.ReviewDequeue.self,
    UseCase.ReviewEnqueue.self,
    UseCase.ReviewLabels.self,
    UseCase.ReviewList.self,
    UseCase.ReviewOwnage.self,
    UseCase.ReviewPatch.self,
    UseCase.ReviewRebase.self,
    UseCase.ReviewRemind.self,
    UseCase.ReviewSkip.self,
    UseCase.ReviewUpdate.self,
    UseCase.UserActivity.self,
    UseCase.UserRegister.self,
    UseCase.UserWatchAuthors.self,
    UseCase.UserWatchTeams.self,
  ]}
  public static func pack<Payload: ContractPerformer>(
    job: UInt,
    version: String,
    payload: Payload,
    encoder: JSONEncoder
  ) throws -> [Variable] {
    let payload = try encoder.encode(payload).base64EncodedString()
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
      value: encoder
        .encode(Self(job: job, chunks: count, version: version, subject: Payload.subject))
        .base64EncodedString()
    ))
    return result
  }
  public static func unpack(
    env: [String: String],
    decoder: JSONDecoder
  ) throws -> Self {
    guard let data = try Data(base64Encoded: contract.get(env: env))
    else { throw Thrown("Contract not base64 encoded") }
    return try decoder.decode(Self.self, from: data)
  }
  public struct Variable: Encodable {
    public var key: String
    public var value: String
    public static func make(key: String, value: String) -> Self {
      .init(key: key, value: value)
    }
  }
  public struct Payload: Encodable {
    public var ref: String
    public var variables: [Variable]
    public static func make(ref: String, variables: [Variable]) -> Self {
      .init(ref: ref, variables: variables)
    }
  }
}
