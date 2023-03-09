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
    guard let cfg = try ctx.parseGitlab() else { throw Thrown("No gitlab in profile") }
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
  public func contractReview(_ payload: ContractPayload) throws -> Bool {
    guard case .value = gitlab.current.review else { throw Thrown("Not review job") }
    try triggerPipeline(variables: payload.encode(
      job: gitlab.current.id, version: repo.profile.version
    ))
    return true
  }
  public func contractProtected(_ payload: ContractPayload) throws -> Bool {
    let protected = try gitlab.protected.get()
    try createPipeline(protected: protected, variables: payload.encode(
      job: gitlab.current.id, version: repo.profile.version
    ))
    return true
  }
  public func contract(_ payload: ContractPayload) throws -> Bool {
    let variables = try payload.encode(job: gitlab.current.id, version: repo.profile.version)
    if let protected = try? gitlab.protected.get() {
      try createPipeline(protected: protected, variables: variables)
    } else if case .value = gitlab.current.review {
      try triggerPipeline(variables: variables)
    } else {
      throw Thrown("Not either review or protected ref job")
    }
    return true
  }
  public func exportFusion(fork: String, source: String) throws -> Bool {
    let fork = try Ctx.Git.Sha.make(value: fork)
    let source = try Ctx.Git.Branch.make(name: source)
    let pretected = try gitlab.protected.get()
    var targets = try gitlab.protected
      .map(listBranches(protected:))
      .get()
      .filter(\.protected)
      .map(\.name)
      .map(Ctx.Git.Branch.make(name:))
      .filter({ (try? repo.git.mergeBase(sh: sh, $0.remote, fork.ref)) != nil })
      .reduce(into: Set(), { $0.insert($1) })
    targets.remove(source)
    guard targets.isEmpty.not else { return false }
    let integrate = targets.sorted()
    let propogate = try integrate
      .filter({ try repo.git.check(sh: sh, child: $0.remote, parent: fork.ref) })
    let duplicate = try repo.git.listParents(sh: sh, ref: fork.ref).count == 1
    try sh.stdout(sh.rawEncoder.encode(Json.FusionTargets.make(
      fork: fork,
      source: source,
      integrate: integrate,
      duplicate: duplicate,
      propogate: propogate
    )))
    return true
  }
}
extension GitlabSender {
  func triggerPipeline(variables: [Contract.Payload.Variable]) throws { try Id
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
  func createPipeline(
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
  func listBranches(protected: Ctx.Gitlab.Protected) throws -> [Json.GitlabBranch] {
    var result: [Json.GitlabBranch] = []
    var page = 1
    while true {
      let branches = try Id
        .make(Execute.makeCurl(
          url: "\(gitlab.project)/repository/branches?page=\(page)&per_page=100",
          method: "POST",
          retry: 2,
          headers: ["Authorization: Bearer \(protected.rest)", Json.utf8],
          secrets: [protected.rest]
        ))
        .map(sh.execute)
        .reduce([Json.GitlabBranch].self, gitlab.apiDecoder.decode(success:reply:))
        .get()
      result += branches
      guard branches.count == 100 else { return result }
      page += 1
    }
  }

#warning("TBD implement default branch clockwork version check")
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
