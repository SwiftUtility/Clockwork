import Foundation
import Facility
import FacilityPure
public final class GitlabProtected: ContextProtected {
  public func protected() throws -> ContextProtected { self }
  public let sh: Ctx.Sh
  public let git: Ctx.Git
  public let repo: Ctx.Repo
  public let gitlab: Ctx.Gitlab
  public let rest: String
  public let project: Json.GitlabProject
  public init(sender: GitlabSender) throws {
    self.sh = sender.sh
    self.git = sender.git
    self.repo = sender.repo
    self.gitlab = sender.gitlab
    self.rest = try sender.parse(secret: gitlab.cfg.apiToken)
    self.project = try Id
      .make(Execute.makeCurl(
        url: gitlab.project,
        headers: ["Authorization: Bearer \(rest)"],
        secrets: [rest]
      ))
      .map(sh.execute)
      .map(Execute.parseData(reply:))
      .reduce(Json.GitlabProject.self, gitlab.apiDecoder.decode(_:from:))
      .get()
  }

}
