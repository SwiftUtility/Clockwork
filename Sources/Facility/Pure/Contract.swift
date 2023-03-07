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
    }
  }
  public struct PatchReview: ContractPayload {
    public var skip: Bool
    public var args: [String]
    public var patch: Data?
    public static func make(
      skip: Bool, args: [String], patch: Data?
    ) -> Self { .init(
      skip: skip, args: args, patch: patch
    )}
  }
  struct Accept: ContractPayload {
    public var args: [String]
    public static func make(
      args: [String]
    ) -> Self { .init(
      args: args
    )}
  }
  struct AddLabels: ContractPayload {
    var labels: [String]
    var trigger: Bool
    public static func make(
      labels: [String], trigger: Bool
    ) -> Self { .init(
      labels: labels, trigger: trigger
    )}
  }
  struct Approve: ContractPayload {
    var advance: Bool
    public static func make(
      advance: Bool
    ) -> Self { .init(
      advance: advance
    )}
  }
  struct Dequeue: ContractPayload {
    var iid: UInt
    public static func make(
      advance: Bool
    ) -> Self { .init(
      advance: advance
    )}
  }
  struct Enqueue: ContractPayload {
    static var abstract: String { "Update parent review state" }
    @OptionGroup var clockwork: Clockwork
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct ExportTargets: ContractPayload {
    static var abstract: String { "Render integration suitable branches to stdout" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Context to make available during rendering")
    var args: [String] = []
    @Flag(help: "Should read stdin and pass as a context for generation")
    var stdin: Common.Stdin = .ignore
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct List: ContractPayload {
    static var abstract: String { "List all reviews to be approved" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Approver login or all active users")
    var user: String = ""
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct Own: ContractPayload {
    static var abstract: String { "Add user to authors" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Approver login or job runner")
    var user: String = ""
    @Option(help: "Merge request iid or parent merge iid")
    var iid: UInt = 0
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct Patch: ContractPayload {
    static var abstract: String { "Apply patch to current MR sha" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should skip commit approval")
    var skip: Bool = false
    @Argument(help: "Additional context")
    var args: [String] = []
    func execute(ctx: Shell) throws { try Contract.PatchReview
      .make(skip: skip, args: args, patch: ctx.sh.stdin())
      .supportGitlabReview(ctx: ctx)
    }
  }
  struct Rebase: ContractPayload {
    static var abstract: String { "Rebase parent review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Merge request iid or parent merge iid")
    var iid: UInt = 0
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct Remind: ContractPayload {
    static var abstract: String { "Ask approvers to pay attention" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Merge request iid or parent merge iid")
    var iid: UInt = 0
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct RemoveLabels: ContractPayload {
    static var abstract: String { "Remove parent review labels" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Labels to be removed from parent review")
    var labels: [String]
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct ReserveBuild: ContractPayload {
    static var abstract: String { "Reserve build number for parrent review pipeline" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Product name to make branch for")
    var product: String
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct TriggerPipeline: ContractPayload {
    static var abstract: String { "Create new pipeline for parent review" }
    @OptionGroup var clockwork: Clockwork
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct Skip: ContractPayload {
    static var abstract: String { "Mark review as emergent" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Merge request iid")
    var iid: UInt
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct StartDuplication: ContractPayload {
    static var abstract: String { "Create duplication review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Duplicated commit sha")
    var fork: String
    @Option(help: "Duplication target branch name")
    var target: String
    @Option(help: "Duplication source branch name")
    var source: String
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct StartIntegration: ContractPayload {
    static var abstract: String { "Create integration review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Integrated commit sha")
    var fork: String
    @Option(help: "Integration target branch name")
    var target: String
    @Option(help: "Integration source branch name")
    var source: String
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct StartPropogation: ContractPayload {
    static var abstract: String { "Create propogation review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Propogated commit sha")
    var fork: String
    @Option(help: "Propogation target branch name")
    var target: String
    @Option(help: "Propogation source branch name")
    var source: String
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct StartReplication: ContractPayload {
    static var abstract: String { "Create replication review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Propogated commit sha")
    var fork: String
    @Option(help: "Propogation target branch name")
    var target: String
    @Option(help: "Propogation source branch name")
    var source: String
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct Unown: ContractPayload {
    static var abstract: String { "Remove user from authors" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Approver login or job runner")
    var user: String = ""
    @Option(help: "Merge request iid or parent merge iid")
    var iid: UInt = 0
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
  struct Update: ContractPayload {
    static var abstract: String { "Update status for stuck reviews" }
    @OptionGroup var clockwork: Clockwork
    func execute(ctx: Shell) throws {
      #warning("TBD")
    }
  }
}
