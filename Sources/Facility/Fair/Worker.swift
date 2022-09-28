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
    return .init(
      gitlab: gitlabCi,
      job: job,
      profile: parent.profile,
      review: review
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
  func resolveAuauthor(
    cfg: Configuration,
    ctx: ParentReview,
    kind: Fusion.Kind
  ) throws -> String {
    guard kind.merge != nil else { return ctx.review.author.username }
    let bot = try ctx.gitlab.protected.get().user.username
    let sha = try findFirstProposition(
      cfg: cfg,
      ref: .make(sha: .init(value: ctx.job.pipeline.sha))
    )
    return try ctx.gitlab
      .listShaMergeRequests(sha: sha)
      .map(execute)
      .reduce([Json.GitlabCommitMergeRequest].self, jsonDecoder.decode(success:reply:))
      .get()
      .filter { $0.projectId == ctx.gitlab.job.pipeline.projectId }
      .filter { $0.squashCommitSha == sha.value }
      .filter { $0.author.username != bot }
      .first
      .map(\.author.username)
      .get { throw Thrown("No author for \(sha.value)") }
  }
  func findFirstProposition(
    cfg: Configuration,
    ref: Git.Ref
  ) throws -> Git.Sha {
    let parents = try Execute.parseLines(reply: execute(cfg.git.listParents(ref: ref)))
    guard parents.count > 1 else {
      return try .init(value: Execute.parseText(reply: execute(cfg.git.getSha(ref: ref))))
    }
    return try findFirstProposition(cfg: cfg, ref: ref.make(parent: 2))
  }
  func resolveCoauthors(
    cfg: Configuration,
    ctx: ParentReview,
    kind: Fusion.Kind
  ) throws -> [String: String] {
    let bot = try ctx.gitlab.protected.get().user.username
    guard let merge = kind.merge else { return [:] }
    let commits = try Execute.parseLines(reply: execute(cfg.git.listCommits(
      in: [.make(sha: merge.fork)],
      notIn: [.make(remote: merge.target)],
      noMerges: true,
      firstParents: false
    )))
    var result: [String: String] = [:]
    for commit in commits { try ctx.gitlab
      .listShaMergeRequests(sha: .init(value: commit))
      .map(execute)
      .reduce([Json.GitlabCommitMergeRequest].self, jsonDecoder.decode(success:reply:))
      .get()
      .filter { $0.projectId == ctx.gitlab.job.pipeline.projectId }
      .filter { $0.squashCommitSha == commit }
      .filter { $0.author.username != bot }
      .forEach { result["\($0.iid)"] = $0.author.username }
    }
    return result
  }
  func isLastPipe(ctx: ParentReview) -> Bool {
    guard ctx.job.pipeline.id == ctx.review.pipeline.id else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    guard ctx.review.state == "opened" else {
      logMessage(.init(message: "Review must be opened"))
      return false
    }
    guard ctx.job.pipeline.sha == ctx.review.pipeline.sha else {
      logMessage(.init(message: "Review commit mismatch"))
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
    public func makeBuild(build: String) -> Production.Build { .review(.make(
      build: build,
      sha: job.pipeline.sha,
      review: review.iid,
      target: review.targetBranch
    ))}
  }
}
