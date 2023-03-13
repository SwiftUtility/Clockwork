import Foundation
import Facility
import FacilityPure
extension ContextGitlab {
  func triggerPipeline(ref: String, variables: [Contract.Variable]) throws { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.api)/projects/\(gitlab.current.pipeline.projectId)/trigger/pipeline",
      method: "POST",
      form: [
        "token=\(gitlab.token)",
        "ref=\(ref)",
      ] + variables.map({ "variables[\($0.key)]=\($0.value)" }),
      headers: ["Authorization: Bearer \(gitlab.token)"],
      secrets: [gitlab.token]
    ))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func createPipeline(
    ref: String,
    protected: Ctx.Gitlab.Protected,
    variables: [Contract.Variable]
  ) throws { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.api)/projects/\(gitlab.current.pipeline.projectId)/pipeline",
      method: "POST",
      data: String.make(utf8: gitlab.apiEncoder.encode(Contract.Payload.make(
        ref: ref,
        variables: variables
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
}
