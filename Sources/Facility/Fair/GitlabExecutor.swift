import Foundation
import Facility
import FacilityPure
public final class GitlabExecutor: ContextExclusive {
  public let sh: Ctx.Sh
  public let git: Ctx.Git
  public let repo: Ctx.Repo
  public let gitlab: Ctx.Gitlab
  public let protected: Ctx.Gitlab.Protected
  public let storage: Ctx.Storage = .init()
  public let generate: Try.Of<Generate>.Do<String>
  public init(
    sender: GitlabSender,
    generate: @escaping Try.Of<Generate>.Do<String>
  ) throws {
    self.sh = sender.sh
    self.git = sender.git
    self.repo = sender.repo
    self.gitlab = sender.gitlab
    self.protected = try sender.protected()
    self.generate = generate
  }
  public func execute() throws -> Bool {
    let info = try Contract.unpack(env: sh.env, decoder: sh.rawDecoder)
    #warning("TBD implement default branch clockwork version check")
    #warning("TBD implement contract version check")
    guard let payload = Contract.payloads.first(where: { $0.subject == info.subject })
    else { throw Thrown("Unknown command \(info.subject)") }
    try info.unpack(payload: payload, env: sh.env, decoder: sh.rawDecoder)
    #warning("TBD")
    return false
  }
  public func send(report: Report) {
    #warning("TBD")
  }
}
//  public func fulfillContract(cfg: Configuration) throws -> Bool {
//    let contract = try Contract.decode(env: cfg.env, decoder: jsonDecoder)
//    if let subject = try Contract.PatchReview.decode(
//      contract: contract, env: cfg.env, decoder: jsonDecoder
//    ) {
//      #warning("TBD")
//    }
//    return false
//  }
//  public func sendContract(gitlab: Gitlab, payload: ContractPayload) throws {
//    let string = try jsonEncoder.encode(payload).base64EncodedString()
//    gitlab.postTriggerPipeline(ref: gitlab.contract.ref.value, forms: variables)
//  }
//}
