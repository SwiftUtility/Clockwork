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
    let gitlabCi = try cfg.gitlabCi.get()
    let parent = try gitlabCi.env.parent.get()
    let job = try gitlabCi.getJob(id: parent.job)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    let review = try job.review
      .flatMap(gitlabCi.getMrState(review:))
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    if job.pipeline.id != review.pipeline.id {
      logMessage(.init(message: "Pipeline outdated"))
    }
    if review.state != "opened" {
      logMessage(.init(message: "Review state: \(review.state)"))
    }
    return .init(
      gitlab: gitlabCi,
      job: job,
      profile: parent.profile,
      review: review,
      isLastPipe: job.pipeline.id == review.pipeline.id
    )
  }
  func resolveProject(cfg: Configuration) throws -> Json.GitlabProject { try cfg
    .gitlabCi
    .flatMap(\.getProject)
    .map(execute)
    .reduce(Json.GitlabProject.self, jsonDecoder.decode(success:reply:))
    .get()
  }
  func resolveBranch(cfg: Configuration, name: String) throws -> Json.GitlabBranch { try cfg
    .gitlabCi
    .flatReduce(curry: name, GitlabCi.getBranch(name:))
    .map(execute)
    .reduce(Json.GitlabBranch.self, jsonDecoder.decode(success:reply:))
    .get()
  }
  func resolveProtectedBranches(cfg: Configuration) throws -> [Git.Branch] {
    var result: [Git.Branch] = []
    var page = 1
    let gitlab = try cfg.gitlabCi.get()
    while true {
      let branches = try gitlab
        .getBranches(page: page, count: 100)
        .map(execute)
        .reduce([Json.GitlabBranch].self, jsonDecoder.decode(success:reply:))
        .get()
      result += try branches
        .filter(\.protected)
        .map(\.name)
        .map(Git.Branch.init(name:))
      guard branches.count == 100 else { return result }
      page += 1
    }
  }
  func resolveAuthors(
    cfg: Configuration,
    state: Json.GitlabReviewState,
    kind: Fusion.Kind
  ) throws -> Set<String> {
    let gitlab = try cfg.gitlabCi.get()
    guard let merge = kind.merge else { return [state.author.username] }
    let bot = try cfg.gitlabCi.get().protected.get().user.username
    let commits = try Execute.parseLines(reply: execute(cfg.git.listCommits(
      in: [.make(sha: merge.fork)],
      notIn: [.make(remote: merge.target)],
      noMerges: true
    )))
    var result: Set<String> = []
    for commit in commits { try gitlab
      .listShaMergeRequests(sha: .make(value: commit))
      .map(execute)
      .reduce([Json.GitlabCommitMergeRequest].self, jsonDecoder.decode(success:reply:))
      .get()
      .filter { $0.projectId == gitlab.job.pipeline.projectId }
      .filter { $0.squashCommitSha == commit }
      .filter { $0.author.username != bot }
      .forEach { result.insert($0.author.username) }
    }
    return result
  }
  struct ParentReview {
    let gitlab: GitlabCi
    let job: Json.GitlabJob
    let profile: Files.Relative
    let review: Json.GitlabReviewState
    let isLastPipe: Bool
    var isActual: Bool { return isLastPipe && review.state == "opened" }
  }
}
