import Foundation
import Facility
public protocol ContractPayload: Codable {
  static var subject: String { get }
}
extension ContractPayload {
  public static var subject: String { "\(Self.self)" }
  public func encode(job: UInt, version: String) throws -> [Contract.Payload.Variable] {
    let encoder = JSONEncoder()
    let payload = try encoder.encode(self).base64EncodedString()
    var count: UInt = 0
    var startIndex = payload.startIndex
    var result: [Contract.Payload.Variable] = []
    while startIndex < payload.endIndex {
      let endIndex = payload
        .index(startIndex, offsetBy: Contract.chunkSize, limitedBy: payload.endIndex)
        .get(payload.endIndex)
      result.append(.init(
        key: "\(Contract.env)_\(count)",
        value: String(payload[startIndex..<endIndex])
      ))
      count += 1
      startIndex = endIndex
    }
    try result.append(.init(
      key: Contract.env,
      value: encoder
        .encode(Contract(job: job, chunks: count, version: version, subject: Self.subject))
        .base64EncodedString()
    ))
    return result
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
  public static func buildReserve(
    product: String
  ) -> BuildReserve { .init(
    product: product
  )}
  public static func reviewPatch(
    skip: Bool, args: [String], patch: Data?
  ) -> ReviewPatch { .init(
    skip: skip, args: args, patch: patch
  )}
  public static func reviewLabels(
    labels: [String], add: Bool
  ) -> ReviewLabels { .init(
    labels: labels, add: add
  )}
  public static func reviewApprove(
    advance: Bool
  ) -> ReviewApprove { .init(
    advance: advance
  )}
  public static func reviewDequeue(
    iid: UInt
  ) -> ReviewDequeue { .init(
    iid: iid
  )}
  public static func reviewEnqueue(
    jobs: [String]
  ) -> ReviewEnqueue { .init(
    jobs: jobs
  )}
  public static func reviewList(
    user: String
  ) -> ReviewList { .init(
    user: user
  )}
  public static func reviewOwnage(
    user: String, iid: UInt, own: Bool
  ) -> ReviewOwnage { .init(
    user: user, iid: iid, own: own
  )}
  public static func reviewSkip(
    iid: UInt
  ) -> ReviewSkip { .init(
    iid: iid
  )}
  public static func fusionStart(
    fork: String, target: String, source: String, prefix: Review.Fusion.Prefix
  ) -> FusionStart { .init(
    fork: fork, target: target, source: source, prefix: prefix
  )}
  public static func userAcvivity(
    login: String, active: Bool
  ) -> UserAcvivity { .init(
    login: login, active: active
  )}
  public static func userRegister(
    login: String, slack: String, rocket: String
  ) -> UserRegister { .init(
    login: login, slack: slack, rocket: rocket
  )}
  public static func userWatch(
    login: String, update: [String], kind: UserWatch.Kind
  ) -> UserWatch { .init(
    login: login, update: update, kind: kind
  )}
  public static func сonnectSignal(
    event: String, args: [String], stdin: AnyCodable?
  ) -> ConnectSignal { .init(
    event: event, args: args, stdin: stdin
  )}
  public static func flowChangeAccessory(
    product: String, branch: String, version: String
  ) -> FlowChangeAccessory { .init(
    product: product,
    branch: branch,
    version: version
  )}
  public static func flowChangeNext(
    product: String, version: String
  ) -> FlowChangeNext { .init(
    product: product,
    version: version
  )}
  public static func flowCreateAccessory(
    name: String, commit: String
  ) -> FlowCreateAccessory { .init(
    name: name,
    commit: commit
  )}
  public static func flowCreateDeploy(
    branch: String, commit: String
  ) -> FlowCreateDeploy { .init(
    branch: branch,
    commit: commit
  )}
  public static func flowCreateStage(
    product: String, build: String
  ) -> FlowCreateStage { .init(
    product: product,
    build: build
  )}
  public static func flowDeleteBranch(
    name: String
  ) -> FlowDeleteBranch { .init(
    name: name
  )}
  public static func flowDeleteTag(
    name: String
  ) -> FlowDeleteTag { .init(
    name: name
  )}
  public static func flowReserveBuild(
    product: String
  ) -> FlowReserveBuild { .init(
    product: product
  )}
  public static func flowStartHotfix(
    product: String, commit: String, version: String
  ) -> FlowStartHotfix { .init(
    product: product,
    commit: commit,
    version: version
  )}
  public static func flowStartRelease(
    product: String, commit: String
  ) -> FlowStartRelease { .init(
    product: product,
    commit: commit
  )}
  public struct Subject<Payload: ContractPayload> {
    public var contract: Contract
    public var payload: Payload
  }
  public struct Payload: Encodable {
    public var ref: String
    public var variables: [Variable]
    public static func make(ref: String, variables: [Variable]) -> Self { .init(
      ref: ref, variables: variables
    )}
    public struct Variable: Encodable {
      public var key: String
      public var value: String
      public static func make(key: String, value: String) -> Self { .init(key: key, value: value) }
    }
  }
  public struct BuildReserve: ContractPayload {
    public var product: String
  }
  public struct FusionStart: ContractPayload {
    public var fork: String
    public var target: String
    public var source: String
    public var prefix: Review.Fusion.Prefix
  }
  public struct ReviewApprove: ContractPayload {
    public var advance: Bool
  }
  public struct ReviewDequeue: ContractPayload {
    public var iid: UInt
  }
  public struct ReviewEnqueue: ContractPayload {
    public var jobs: [String]
  }
  public struct ReviewLabels: ContractPayload {
    public var labels: [String]
    public var add: Bool
  }
  public struct ReviewList: ContractPayload {
    public var user: String
  }
  public struct ReviewOwnage: ContractPayload {
    public var user: String
    public var iid: UInt
    public var own: Bool
  }
  public struct ReviewPatch: ContractPayload {
    public var skip: Bool
    public var args: [String]
    public var patch: Data?
  }
  public enum Perform: String, ContractPayload {
    case acceptReview
    case updateReview
    case rebaseReview
    case remindReview
    case cleanConnect
  }
  public struct ReviewSkip: ContractPayload {
    public var iid: UInt
  }
  public struct UserAcvivity: ContractPayload {
    public var login: String
    public var active: Bool
  }
  public struct UserRegister: ContractPayload {
    public var login: String
    public var slack: String
    public var rocket: String
  }
  public struct UserWatch: ContractPayload {
    public var login: String
    public var update: [String]
    public var kind: Kind
    public enum Kind: String, Codable {
      case addTeams
      case delTeams
      case addAuthors
      case delAuthors
    }
  }
  public struct ConnectSignal: ContractPayload {
    public var event: String
    public var args: [String]
    public var stdin: AnyCodable?
  }
  public struct FlowChangeAccessory: ContractPayload {
    var product: String
    var branch: String
    var version: String
  }
  public struct FlowChangeNext: ContractPayload {
    var product: String
    var version: String
  }
  public struct FlowCreateAccessory: ContractPayload {
    var name: String
    var commit: String
  }
  public struct FlowCreateDeploy: ContractPayload {
    var branch: String
    var commit: String
  }
  public struct FlowCreateStage: ContractPayload {
    var product: String
    var build: String
  }
  public struct FlowDeleteBranch: ContractPayload {
    var name: String
  }
  public struct FlowDeleteTag: ContractPayload {
    var name: String
  }
  public struct FlowReserveBuild: ContractPayload {
    var product: String
  }
  public struct FlowStartHotfix: ContractPayload {
    var product: String
    var commit: String
    var version: String
  }
  public struct FlowStartRelease: ContractPayload {
    var product: String
    var commit: String
  }
}
