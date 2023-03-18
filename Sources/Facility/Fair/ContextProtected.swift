import Foundation
import Facility
import FacilityPure
extension ContextProtected {
  func createPipeline(
    ref: String,
    variables: [Contract.Variable]
  ) throws { try Id
      .make(Execute.makeCurl(
        url: "\(gitlab.api)/projects/\(gitlab.current.pipeline.projectId)/pipeline",
        method: "POST",
        data: String.make(utf8: gitlab.apiEncoder.encode(Contract.Payload.make(
          ref: ref,
          variables: variables
        ))),
        headers: ["Authorization: Bearer \(rest)", Json.utf8],
        secrets: [rest]
      ))
      .map(sh.execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  func listBranches() throws -> [Json.GitlabBranch] {
    var result: [Json.GitlabBranch] = []
    var page = 1
    while true {
      let branches = try Id
        .make(Execute.makeCurl(
          url: "\(gitlab.project)/repository/branches?page=\(page)&per_page=100",
          method: "POST",
          retry: 2,
          headers: ["Authorization: Bearer \(rest)", Json.utf8],
          secrets: [rest]
        ))
        .map(sh.execute)
        .reduce([Json.GitlabBranch].self, gitlab.apiDecoder.decode(success:reply:))
        .get()
      result += branches
      guard branches.count == 100 else { return result }
      page += 1
    }
  }
  func getJob(id: UInt) throws -> Json.GitlabJob { try Id
      .make(Execute.makeCurl(
        url: "\(gitlab.project)/jobs/\(id)",
        retry: 2,
        headers: ["Authorization: Bearer \(rest)", Json.utf8],
        secrets: [rest]
      ))
      .map(sh.execute)
      .reduce(Json.GitlabJob.self, gitlab.apiDecoder.decode(success:reply:))
      .get()
  }
  func getTag(name: String) throws -> Json.GitlabTag { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.project)/repository/tags/\(name.urlEncoded())",
      retry: 2,
      headers: ["Authorization: Bearer \(rest)", Json.utf8],
      secrets: [rest]
    ))
    .map(sh.execute)
    .reduce(Json.GitlabTag.self, gitlab.apiDecoder.decode(success:reply:))
    .get()
  }
  func getBranch(name: String) throws -> Json.GitlabBranch { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.project)/repository/branches/\(name.urlEncoded())",
      retry: 2,
      headers: ["Authorization: Bearer \(rest)", Json.utf8],
      secrets: [rest]
    ))
    .map(sh.execute)
    .reduce(Json.GitlabBranch.self, gitlab.apiDecoder.decode(success:reply:))
    .get()
  }
  func getMerge(iid: UInt) throws -> Json.GitlabMerge { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.project)/merge_requests/\(iid)",
      retry: 2,
      headers: ["Authorization: Bearer \(rest)", Json.utf8],
      secrets: [rest]
    ))
    .map(sh.execute)
    .reduce(Json.GitlabMerge.self, gitlab.apiDecoder.decode(success:reply:))
    .get()
  }
  func deleteTag(name: String) throws { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.project)/repository/tags/\(name.urlEncoded())",
      method: "DELETE",
      retry: 2,
      headers: ["Authorization: Bearer \(rest)"],
      secrets: [rest]
    ))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func deleteBranch(name: String) throws { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.project)/repository/branches/\(name.urlEncoded())",
      method: "DELETE",
      retry: 2,
      headers: ["Authorization: Bearer \(rest)"],
      secrets: [rest]
    ))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func getUser() throws -> Json.GitlabUser { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.api)/user",
      retry: 2,
      headers: ["Authorization: Bearer \(rest)"],
      secrets: [rest]
    ))
    .map(sh.execute)
    .reduce(Json.GitlabUser.self, gitlab.apiDecoder.decode(success:reply:))
    .get()
  }
  func createBranches(
    name: String,
    commit: Ctx.Git.Sha
  ) throws -> Json.GitlabBranch { try Id
    .make(Execute.makeCurl(
      url: "\(gitlab.project)/repository/branches",
      method: "POST",
      form: [
        "branch=\(name.urlEncoded())",
        "ref=\(commit.value)",
      ],
      headers: ["Authorization: Bearer \(rest)"],
      secrets: [rest]
    ))
    .map(sh.execute)
    .reduce(Json.GitlabBranch.self, gitlab.apiDecoder.decode(success:reply:))
    .get()
  }
}
