import Foundation
import Facility
import FacilityPure
public final class Mediator {
  let execute: Try.Reply<Execute>
  let logMessage: Act.Reply<LogMessage>
  let worker: Worker
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    logMessage: @escaping Act.Reply<LogMessage>,
    worker: Worker,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.logMessage = logMessage
    self.worker = worker
    self.jsonDecoder = jsonDecoder
  }
  public func triggerPipeline(
    cfg: Configuration,
    ref: String,
    context: [String]
  ) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    var variables: [String: String] = [:]
    for variable in context {
      let index = try variable.firstIndex(of: "=")
        .get { throw Thrown("wrong argument format \(variable)") }
      let key = variable[variable.startIndex..<index]
      let value = variable[index..<variable.endIndex].dropFirst()
      variables[.init(key)] = .init(value)
    }
    variables[gitlabCi.trigger.jobId] = "\(gitlabCi.job.id)"
    variables[gitlabCi.trigger.jobName] = gitlabCi.job.name
    variables[gitlabCi.trigger.profile] = cfg.profile.profile.path.value
    variables[gitlabCi.trigger.pipeline] = "\(gitlabCi.job.pipeline.id)"
    try gitlabCi
      .postTriggerPipeline(cfg: cfg, ref: ref, variables: variables)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func createReviewPipeline(
    cfg: Configuration
  ) throws -> Bool {
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    try ctx.gitlab.postMrPipelines(review: ctx.review.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func addReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    let labels = Set(labels).subtracting(.init(ctx.review.labels))
    guard !labels.isEmpty else {
      logMessage(.init(message: "No new labels"))
      return false
    }
    try ctx.gitlab
      .putMrState(
        parameters: .init(addLabels: labels.joined(separator: ",")),
        review: ctx.review.iid
      )
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    logMessage(.init(message: "Labels added"))
    return true
  }
  public func removeReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    let labels = Set(labels).intersection(.init(ctx.review.labels))
    guard !labels.isEmpty else {
      logMessage(.init(message: "Labels not present"))
      return false
    }
    try ctx.gitlab
      .putMrState(
        parameters: .init(removeLabels: labels.joined(separator: ",")),
        review: ctx.review.iid
      )
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    logMessage(.init(message: "Labels removed"))
    return true
  }
  public func affectJobs(
    configuration cfg: Configuration,
    pipeline: String,
    names: [String],
    action: GitlabCi.JobAction
  ) throws -> Bool {
    let gitlabCi = try cfg.gitlabCi.get()
    let pipeline = try pipeline.getUInt()
    var page = 1
    var jobs: [Json.GitlabJob] = []
    while true {
      jobs += try gitlabCi
        .getJobs(action: action, pipeline: pipeline, page: page, count: 100)
        .map(execute)
        .reduce([Json.GitlabJob].self, jsonDecoder.decode(success:reply:))
        .get()
      if jobs.count == page * 100 { page += 1 } else { break }
    }
    let names = Set(names)
    let ids = jobs
      .filter({ names.contains($0.name) })
      .reduce(into: [:], { $0[$1.name] = max($0[$1.name].get($1.id), $1.id) })
      .values
    guard ids.count == names.count else { return false }
    for id in ids { try Execute.checkStatus(
      reply: execute(gitlabCi.postJobsAction(job: id, action: action).get())
    )}
    return true
  }
}
