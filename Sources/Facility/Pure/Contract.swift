import Foundation
import Facility
public protocol ContractPayload: Codable {
  static var subject: String { get }
}
extension ContractPayload {
  public static var subject: String { "\(Self.self)" }
  public func encode(job: UInt, version: String, encoder: JSONEncoder) throws -> [String] {
    let payload = try encoder.encode(self).base64EncodedString()
    var count: UInt = 0
    var startIndex = payload.startIndex
    var chunks: [String] = []
    while startIndex < payload.endIndex {
      let endIndex = payload
        .index(startIndex, offsetBy: Contract.chunkSize, limitedBy: payload.endIndex)
        .get(payload.endIndex)
      chunks.append("variables[\(Contract.env)_\(count)]=\(payload[startIndex..<endIndex])")
      count += 1
      startIndex = endIndex
    }
    let contract = try encoder
      .encode(Contract(job: job, chunks: count, version: version, subject: Self.subject))
      .base64EncodedString()
    return ["variables[\(Contract.env)]=\(contract)"] + chunks
  }
  public static func decode(
    contract: Contract,
    env: [String: String],
    decoder: JSONDecoder
  ) throws -> Contract.Subject<Self>? {
    guard contract.subject == Self.subject else { return nil }
    let base = try (0 ..< contract.chunks)
      .map({ try "\(Contract.env)_\($0)".get(env: env) })
      .joined()
    guard let data = Data(base64Encoded: base)
    else { throw Thrown("Contract payload not base64 encoded") }
    return try .init(contract: contract, payload: decoder.decode(Self.self, from: data))
  }
}
public struct Contract: Codable {
  public var job: UInt
  public var chunks: UInt
  public var version: String
  public var subject: String
  public static var chunkSize: Int { 2047 }
  public static var env: String { "CLOCKWORK_CONTRACT" }
  public static func decode(
    env: [String: String],
    decoder: JSONDecoder
  ) throws -> Self {
    guard let data = try Data(base64Encoded: Contract.env.get(env: env))
    else { throw Thrown("Contract not base64 encoded") }
    return try decoder.decode(Contract.self, from: data)
  }
  public struct Subject<Payload: ContractPayload> {
    public var contract: Contract
    public var payload: Payload
  }
  public struct PatchReview: ContractPayload {
    public var skip: Bool
    public var args: [String]
    public var patch: Data
    public var sha: String
    public static func make(
      skip: Bool, args: [String], patch: Data, sha: String
    ) -> Self { .init(
      skip: skip, args: args, patch: patch, sha: sha
    )}
  }
}
