import Foundation
import Facility
import FacilityPure
public final class GitlabSender: ContextGitlab {
  public let sh: Ctx.Sh
  public let repo: Ctx.Repo
  public let gitlab: Ctx.Gitlab
  public init(ctx: ContextLocal) throws {
    self.sh = ctx.sh
    self.repo = ctx.repo
    guard let cfg = try repo.profile.gitlab
      .reduce(Yaml.Gitlab.self, ctx.parse(type:yaml:))
      .map(Ctx.Gitlab.Cfg.make(yaml:))
    else { throw Thrown("Gitlab not configured") }
    let apiEncoder = JSONEncoder()
    apiEncoder.keyEncodingStrategy = .convertToSnakeCase
    let apiDecoder = JSONDecoder()
    apiDecoder.keyDecodingStrategy = .convertFromSnakeCase
    let api = try ctx.sh.get(env: "CI_API_V4_URL")
    let token = try ctx.sh.get(env: "CI_JOB_TOKEN")
    let job = try Id
      .make(Execute.makeCurl(
        url: "\(api)/job",
        headers: ["Authorization: Bearer \(token)"],
        secrets: [token]
      ))
      .map(sh.execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabJob.self, apiDecoder.decode(_:from:))
      .get()
    let protected = Lossy.make({
      let rest = try ctx.parse(secret: cfg.apiToken)
      let project = try Id
        .make(Execute.makeCurl(
          url: "\(api)/projects/\(job.pipeline.projectId)",
          headers: ["Authorization: Bearer \(token)"],
          secrets: [token]
        ))
        .map(ctx.sh.execute)
        .map(Execute.parseData(reply:))
        .reduce(Json.GitlabProject.self, apiDecoder.decode(_:from:))
        .get()
      return Ctx.Gitlab.Protected.make(rest: rest, proj: project)
    })
    self.gitlab = Ctx.Gitlab.make(
      cfg: cfg,
      api: api,
      token: token,
      protected: protected,
      current: job,
      apiEncoder: apiEncoder,
      apiDecoder: apiDecoder
    )
  }
  public func triggerPipeline(variables: [Contract.Payload.Variable]) throws { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.api)/projects/\(gitlab.current.pipeline.projectId)/trigger/pipeline",
      method: "POST",
      form: [
        "token=\(gitlab.token)",
        "ref=\(gitlab.cfg.contract.ref.value)",
      ] + variables.map({ "variables[\($0.key)]=\($0.value)" }),
      headers: ["Authorization: Bearer \(gitlab.token)"],
      secrets: [gitlab.token]
    ))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  public func createPipeline(
    protected: Ctx.Gitlab.Protected,
    variables: [Contract.Payload.Variable]
  ) throws { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.api)/projects/\(gitlab.current.pipeline.projectId)/pipeline",
      method: "POST",
      data: String.make(utf8: gitlab.apiEncoder.encode(Contract.Payload.make(
        ref: protected.proj.defaultBranch, variables: variables
      ))),
      headers: ["Authorization: Bearer \(protected.rest)", Json.utf8],
      secrets: [protected.rest]
    ))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
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
}
