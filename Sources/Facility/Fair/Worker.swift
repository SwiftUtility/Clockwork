import Foundation
import Facility
import FacilityPure
public final class Worker {
  let execute: Try.Reply<Execute>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  func resolveParentReview(cfg: Configuration) throws -> ParentReview {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let parent = try gitlabCi.parent.get()
    let job = try gitlabCi.getJob(id: parent.job)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let review = try job.review
      .flatMap(gitlabCi.getMrState(review:))
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    return .init(
      gitlab: gitlabCi,
      job: job,
      profile: parent.profile,
      review: review
    )
  }
  func resolveParticipants(
    cfg: Configuration,
    gitlabCi: GitlabCi,
    merge: Fusion.Merge
  ) throws -> [String] { try Id
    .make(cfg.git.listCommits(
      in: [.make(sha: merge.fork)],
      notIn: [.make(remote: merge.target)],
      noMerges: true,
      firstParents: false
    ))
    .map(execute)
    .map(Execute.parseLines(reply:))
    .get()
    .map(Git.Sha.init(value:))
    .flatMap { sha in try gitlabCi
      .listShaMergeRequests(sha: sha)
      .map(execute)
      .reduce([Json.GitlabCommitMergeRequest].self, jsonDecoder.decode(success:reply:))
      .get()
      .filter { $0.squashCommitSha == sha.value }
      .map(\.author.username)
    }
  }
  func isLastPipe(ctx: ParentReview) -> Bool {
    guard ctx.job.pipeline.id == ctx.review.pipeline.id, ctx.review.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    return true
  }
  struct ParentReview {
    let gitlab: GitlabCi
    let job: Json.GitlabJob
    let profile: Files.Relative
    let review: Json.GitlabReviewState
    public func matches(build: Production.Build) -> Bool {
      guard case .review(let value) = build else { return false }
      return value.sha == job.pipeline.sha && value.review == review.iid
    }
  }
}
