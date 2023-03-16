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
}
