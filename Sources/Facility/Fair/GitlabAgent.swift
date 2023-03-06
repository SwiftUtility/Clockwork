import Foundation
import Facility
import FacilityPure
public final class GitlabAgent {
  let execute: Try.Reply<Execute>
  let readStdin: Try.Do<Data?>
  let writeStderr: Act.Of<String>.Go
  let jsonEncoder: JSONEncoder
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    readStdin: @escaping Try.Do<Data?>,
    writeStderr: @escaping Act.Of<String>.Go
  ) {
    self.execute = execute
    self.readStdin = readStdin
    self.writeStderr = writeStderr
    self.jsonEncoder = .init()
    self.jsonDecoder = .init()

  }
  public func patchReview(cfg: Configuration, skip: Bool, args: [String]) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    guard let patch = try readStdin() else { throw Thrown("Empty patch") }
    let payload = try Contract.PatchReview
      .make(skip: skip, args: args, patch: patch, sha: gitlab.job.pipeline.sha)
      .encode(job: gitlab.job.id, version: cfg.profile.version, encoder: jsonEncoder)
    try gitlab
      .postTriggerPipeline(ref: gitlab.contract.ref.value, forms: payload)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func fulfillContract(cfg: Configuration) throws -> Bool {
    let contract = try Contract.decode(env: cfg.env, decoder: jsonDecoder)
    if let subject = try Contract.PatchReview.decode(
      contract: contract, env: cfg.env, decoder: jsonDecoder
    ) {
      #warning("TBD")
    }
    return false
  }
//  public func sendContract(gitlab: Gitlab, payload: ContractPayload) throws {
//    let string = try jsonEncoder.encode(payload).base64EncodedString()
//    gitlab.postTriggerPipeline(ref: gitlab.contract.ref.value, forms: variables)
//  }
}
