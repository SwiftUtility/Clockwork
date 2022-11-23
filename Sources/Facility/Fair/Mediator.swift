import Foundation
import Facility
import FacilityPure
public final class Mediator {
  let execute: Try.Reply<Execute>
  let logMessage: Act.Reply<LogMessage>
  let stdoutData: Act.Of<Data>.Go
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    logMessage: @escaping Act.Reply<LogMessage>,
    stdoutData: @escaping Act.Of<Data>.Go,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.logMessage = logMessage
    self.stdoutData = stdoutData
    self.jsonDecoder = jsonDecoder
  }
  public func loadArtifact(
    cfg: Configuration,
    job: UInt,
    path: String
  ) throws -> Bool {
    try cfg.gitlab
      .flatMap({ $0.loadArtifact(job: job, file: path) })
      .map(execute)
      .map(Execute.parseData(reply:))
      .map(stdoutData)
      .get()
    return true
  }
  public func triggerReview(
    cfg: Configuration,
    iid: UInt
  ) throws -> Bool {
    try cfg.gitlab
      .flatReduce(curry: iid, Gitlab.postMrPipelines(review:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func triggerPipeline(
    cfg: Configuration,
    ref: String,
    context: [String]
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    var variables: [String: String] = [:]
    for variable in context {
      let index = try variable.firstIndex(of: "=")
        .get { throw Thrown("wrong argument format \(variable)") }
      let key = variable[variable.startIndex..<index]
      let value = variable[index..<variable.endIndex].dropFirst()
      variables[.init(key)] = .init(value)
    }
    variables[gitlab.trigger.jobId] = "\(gitlab.job.id)"
    variables[gitlab.trigger.jobName] = gitlab.job.name
    variables[gitlab.trigger.profile] = cfg.profile.location.path.value
    variables[gitlab.trigger.pipeline] = "\(gitlab.job.pipeline.id)"
    try gitlab
      .postTriggerPipeline(cfg: cfg, ref: ref, variables: variables)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func affectPipeline(
    cfg: Configuration,
    id: UInt,
    action: Gitlab.PipelineAction
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    try gitlab
      .affectPipeline(cfg: cfg, pipeline: id, action: action)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func affectJobs(
    cfg: Configuration,
    pipeline: UInt,
    names: [String],
    action: Gitlab.JobAction,
    scopes: [Gitlab.JobScope]
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    var page = 1
    var jobs: [Json.GitlabJob] = []
    while true {
      jobs += try gitlab
        .getJobs(action: action, scopes: scopes, pipeline: pipeline, page: page, count: 100)
        .map(execute)
        .reduce([Json.GitlabJob].self, jsonDecoder.decode(success:reply:))
        .get()
      if jobs.count == page * 100 { page += 1 } else { break }
    }
    let ids = jobs
      .filter({ names.contains($0.name) })
      .reduce(into: [:], { $0[$1.name] = max($0[$1.name].get($1.id), $1.id) })
    guard ids.isEmpty.not else { return false }
    for id in ids.values { try Execute.checkStatus(
      reply: execute(gitlab.postJobsAction(job: id, action: action).get())
    )}
    return true
  }
  public func createReviewPipeline(cfg: Configuration) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let review = try gitlab.review.get()
    guard parent.pipeline.id == review.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    try gitlab.postMrPipelines(review: review.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func addReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let review = try gitlab.review.get()
    guard parent.pipeline.id == review.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    let labels = Set(labels)
      .subtracting(review.labels)
      .joined(separator: ",")
    guard !labels.isEmpty else {
      logMessage(.init(message: "No new labels"))
      return false
    }
    try gitlab
      .putMrState(parameters: .init(addLabels: labels), review: review.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    logMessage(.init(message: "Labels added: \(labels)"))
    return true
  }
  public func removeReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let gitlab = try cfg.gitlab.get()
    let parent = try gitlab.parent.get()
    let review = try gitlab.review.get()
    guard parent.pipeline.id == review.lastPipeline.id else {
      logMessage(.pipelineOutdated)
      return false
    }
    let labels = Set(labels)
      .intersection(review.labels)
      .joined(separator: ",")
    guard !labels.isEmpty else {
      logMessage(.init(message: "Labels not present"))
      return false
    }
    try gitlab
      .putMrState(parameters: .init(removeLabels: labels), review: review.iid)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    logMessage(.init(message: "Labels removed: \(labels)"))
    return true
  }
}
