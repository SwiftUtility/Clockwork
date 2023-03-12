import Foundation
import Facility
import FacilityPure
public enum Contract {
  public static var payloads: [ContractPerformer.Type] {[
    ConnectClean.self,
    ConnectSignal.self,
    FlowChangeAccessory.self,
    FlowChangeNext.self,
    FlowCreateAccessory.self,
    FlowCreateDeploy.self,
    FlowCreateStage.self,
    FlowDeleteBranch.self,
    FlowDeleteTag.self,
    FlowReserveBuild.self,
    FlowStartHotfix.self,
    FlowStartRelease.self,
    FusionStart.self,
    ReviewAccept.self,
    ReviewApprove.self,
    ReviewDequeue.self,
    ReviewEnqueue.self,
    ReviewLabels.self,
    ReviewList.self,
    ReviewOwnage.self,
    ReviewPatch.self,
    ReviewRebase.self,
    ReviewRemind.self,
    ReviewSkip.self,
    ReviewUpdate.self,
    UserActivity.self,
    UserRegister.self,
    UserWatch.self,
  ]}
  public struct Execute: Performer {
    public static func make() -> Self { .init() }
    public func perform(repo: FacilityPure.ContextRepo) throws -> Bool {
      #warning("TBD")
      return false
    }
  }
  public struct GitlabInfo: Codable {
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
  public struct ConnectClean: ContractPerformer {
    public static func make() -> Self {
      .init()
    }
  }
  public struct ConnectSignal: ContractPerformer {
    public var event: String
    public var args: [String]
    public var stdin: AnyCodable?
    public static func make(event: String, args: [String], stdin: AnyCodable?) -> Self {
      .init(event: event, args: args, stdin: stdin)
    }
  }
  public struct FlowChangeAccessory: ContractPerformer {
    var product: String
    var branch: String
    var version: String
    public static func make(product: String, branch: String, version: String) -> Self {
      .init(product: product, branch: branch, version: version)
    }
  }
  public struct FlowChangeNext: ContractPerformer {
    var product: String
    var version: String
    public static func make(product: String, version: String) -> Self {
      .init(product: product, version: version)
    }
  }
  public struct FlowCreateAccessory: ContractPerformer {
    var name: String
    var commit: String
    public static func make(name: String, commit: String) -> Self {
      .init(name: name, commit: commit)
    }
  }
  public struct FlowCreateDeploy: ContractPerformer {
    var branch: String
    var commit: String
    public static func make(branch: String, commit: String) -> Self {
      .init(branch: branch, commit: commit)
    }
  }
  public struct FlowCreateStage: ContractPerformer {
    var product: String
    var build: String
    public static func make(
      product: String, build: String
    ) -> Self {
      .init(product: product, build: build)
    }
  }
  public struct FlowDeleteBranch: ContractPerformer {
    var name: String
    public static func make(name: String) -> Self {
      .init(name: name)
    }
  }
  public struct FlowDeleteTag: ContractPerformer {
    var name: String
    public static func make(name: String) -> Self {
      .init(name: name)
    }
  }
  public struct FlowReserveBuild: ContractPerformer {
    var product: String
    public static func make(product: String) -> Self {
      .init(product: product)
    }
  }
  public struct FlowStartHotfix: ContractPerformer {
    var product: String
    var commit: String
    var version: String
    public static func make(product: String, commit: String, version: String) -> Self {
      .init(product: product, commit: commit, version: version)
    }
  }
  public struct FlowStartRelease: ContractPerformer {
    var product: String
    var commit: String
    public static func make(product: String, commit: String) -> Self {
      .init(product: product, commit: commit)
    }
  }
  public struct FusionStart: ContractPerformer {
    public var fork: String
    public var target: String
    public var source: String
    public var prefix: Review.Fusion.Prefix
    public static func make(
      fork: String, target: String, source: String, prefix: Review.Fusion.Prefix
    ) -> Self {
      .init(fork: fork, target: target, source: source, prefix: prefix)
    }
  }
  public struct ReviewAccept: ContractPerformer {
    public static func make() -> Self {
      .init()
    }
  }
  public struct ReviewApprove: ContractPerformer {
    public var advance: Bool
    public static func make(advance: Bool) -> Self {
      .init(advance: advance)
    }
  }
  public struct ReviewDequeue: ContractPerformer {
    public var iid: UInt
    public static func make(iid: UInt) -> Self {
      .init(iid: iid)
    }
  }
  public struct ReviewEnqueue: ContractPerformer {
    public var jobs: [String]
    public static func make(jobs: [String]) -> Self {
      .init(jobs: jobs)
    }
  }
  public struct ReviewLabels: ContractPerformer {
    public var labels: [String]
    public var add: Bool
    public static func make(labels: [String], add: Bool) -> Self {
      .init(labels: labels, add: add)
    }
  }
  public struct ReviewList: ContractPerformer {
    public var user: String
    public var own: Bool
    public static func make(user: String, own: Bool) -> Self {
      .init(user: user, own: own)
    }
  }
  public struct ReviewOwnage: ContractPerformer {
    public var user: String
    public var iid: UInt
    public var own: Bool
    public static func make(user: String, iid: UInt, own: Bool) -> Self {
      .init(user: user, iid: iid, own: own)
    }
  }
  public struct ReviewPatch: ContractPerformer {
    public var skip: Bool
    public var args: [String]
    public var patch: Data?
    public static func make(skip: Bool, args: [String], patch: Data?) -> Self {
      .init(skip: skip, args: args, patch: patch)
    }
  }
  public struct ReviewRebase: ContractPerformer {
    public static func make() -> Self {
      .init()
    }
  }
  public struct ReviewRemind: ContractPerformer {
    public static func make() -> Self {
      .init()
    }
  }
  public struct ReviewSkip: ContractPerformer {
    public var iid: UInt
    public static func make(iid: UInt) -> Self {
      .init(iid: iid)
    }
  }
  public struct ReviewUpdate: ContractPerformer {
    public static func make() -> Self {
      .init()
    }
  }
  public struct UserActivity: ContractPerformer {
    public var login: String
    public var active: Bool
    public static func make(login: String, active: Bool) -> Self {
      .init(login: login, active: active)
    }
  }
  public struct UserRegister: ContractPerformer {
    public var login: String
    public var slack: String
    public var rocket: String
    public static func make(login: String, slack: String, rocket: String) -> Self {
      .init(login: login, slack: slack, rocket: rocket)
    }
  }
  public struct UserWatch: ContractPerformer {
    public var login: String
    public var update: [String]
    public var kind: Kind
    public static func make(login: String, update: [String], kind: Kind) -> Self {
      .init(login: login, update: update, kind: kind)
    }
    public enum Kind: String, Codable {
      case addTeams
      case delTeams
      case addAuthors
      case delAuthors
    }
  }
}
