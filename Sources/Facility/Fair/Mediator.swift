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
    let gitlabCi = try cfg.controls.gitlabCi.get()
    var variables: [String: String] = [:]
    for variable in context {
      let index = try variable.firstIndex(of: "=")
        .get { throw Thrown("wrong argument format \(variable)") }
      let key = variable[variable.startIndex..<index]
      let value = variable[index..<variable.endIndex].dropFirst()
      variables[.init(key)] = .init(value)
    }
    variables[gitlabCi.trigger.job] = "\(gitlabCi.job.id)"
    variables[gitlabCi.trigger.name] = gitlabCi.job.name
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
  public func affectParentJob(
    configuration cfg: Configuration,
    action: GitlabCi.JobAction
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let parent = try gitlabCi.parent.get()
    let job = try gitlabCi.getJob(id: parent.job)
      .map(execute)
      .reduce(Json.GitlabJob.self, jsonDecoder.decode(success:reply:))
      .get()
    try gitlabCi
      .postJobsAction(job: job.id, action: action)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func affectNeighborJob(
    configuration cfg: Configuration,
    name: String,
    action: GitlabCi.JobAction
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let job = try gitlabCi
      .getJobs(action: action, pipeline: gitlabCi.job.pipeline.id)
      .map(execute)
      .reduce([Json.GitlabJob].self, jsonDecoder.decode(success:reply:))
      .get()
      .filter { $0.name == name }
      .sorted { $0.id < $1.id }
      .last
      .get { throw Thrown("Job \(name) not found") }
    try gitlabCi
      .postJobsAction(job: job.id, action: action)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
}
