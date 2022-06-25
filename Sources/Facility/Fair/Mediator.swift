import Foundation
import Facility
import FacilityPure
public final class Mediator {
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
    variables[gitlabCi.trigger.name] = gitlabCi.job.name
    variables[gitlabCi.trigger.review] = gitlabCi.review.map(String.init(_:))
    variables[gitlabCi.trigger.profile] = cfg.profile.profile.path.value
    variables[gitlabCi.trigger.pipeline] = .init(gitlabCi.job.pipeline.id)
    try gitlabCi
      .postTriggerPipeline(ref: ref, cfg: cfg, variables: variables)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func createReviewPipeline(
    cfg: Configuration
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let review = try gitlabCi.getParentMrState
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    guard try gitlabCi.parent.pipeline.get() == review.pipeline.id, review.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    try gitlabCi.postParentMrPipelines
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
  public func addReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let review = try gitlabCi.getParentMrState
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    guard try gitlabCi.parent.pipeline.get() == review.pipeline.id, review.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    let labels = Set(labels).subtracting(.init(review.labels))
    guard !labels.isEmpty else {
      logMessage(.init(message: "No new labels"))
      return false
    }
    try gitlabCi
      .putMrState(parameters: .init(addLabels: labels.joined(separator: ",")))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    logMessage(.init(message: "Labels added"))
    return true
  }
  public func affectParentJob(
    configuration cfg: Configuration,
    name: String,
    action: GitlabCi.JobAction
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let review = try gitlabCi.getParentMrState
      .map(execute)
      .reduce(Json.GitlabReviewState.self, jsonDecoder.decode(success:reply:))
      .get()
    guard try gitlabCi.parent.pipeline.get() == review.pipeline.id, review.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    let job = try gitlabCi
      .getJobs(action: action, pipeline: review.pipeline.id)
      .map(execute)
      .reduce([Json.GitlabJob].self, jsonDecoder.decode(success:reply:))
      .get()
      .first { $0.name == name }
      .get { throw Thrown("Job \(name) not found") }
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
      .first { $0.name == name }
      .get { throw Thrown("Job \(name) not found") }
    try gitlabCi
      .postJobsAction(job: job.id, action: action)
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    return true
  }
}
