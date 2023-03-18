import Foundation
import Facility
import FacilityPure
public final class GitlabExecutor: ContextExclusive {
  public let sh: Ctx.Sh
  public let git: Ctx.Git
  public let repo: Ctx.Repo
  public let gitlab: Ctx.Gitlab
  public let parent: Json.GitlabJob
  public let rest: String
  public let project: Json.GitlabProject
  public let storage: Ctx.Storage = .init()
  public let flow: Flow?
  public let generate: Try.Of<Generate>.Do<String>
  public init(
    protected ctx: GitlabProtected,
    parent: UInt,
    generate: @escaping Try.Of<Generate>.Do<String>
  ) throws {
    self.sh = ctx.sh
    self.git = ctx.git
    self.repo = ctx.repo
    self.gitlab = ctx.gitlab
    self.rest = ctx.rest
    self.project = ctx.project
    self.parent = try ctx.getJob(id: parent)
    self.generate = generate
    self.flow = try ctx.parseFlow()
    if let flow = flow { storage.flow = try ctx.parseStorage(flow: flow) }
  }
  public func protected() throws -> ContextGitlabProtected { self }
  public func send(report: Report) {
    #warning("TBD")
  }
  public func getFlow() throws -> Flow {
    guard let flow = flow else { throw Thrown("No flow in profile") }
    return flow
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
