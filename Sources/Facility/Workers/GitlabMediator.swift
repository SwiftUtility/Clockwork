import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabMediator {
  let handleApi: Try.Reply<GitlabCi.HandleApi>
  let logMessage: Act.Reply<LogMessage>
  let dialect: AnyCodable.Dialect
  public init(
    handleApi: @escaping Try.Reply<GitlabCi.HandleApi>,
    logMessage: @escaping Act.Reply<LogMessage>,
    dialect: AnyCodable.Dialect
  ) {
    self.handleApi = handleApi
    self.logMessage = logMessage
    self.dialect = dialect
  }
  public func triggerTargetPipeline(
    cfg: Configuration,
    ref: String,
    context: [String]
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    var variables: [String: String] = [:]
    for variable in context {
      let index = try variable.firstIndex(of: "=")
        .or { throw Thrown("wrong argument format \(variable)") }
      let key = variable[variable.startIndex..<index]
      let value = variable[index..<variable.endIndex].dropFirst()
      variables[.init(key)] = .init(value)
    }
    _ = try gitlabCi
      .postTriggerPipeline(
        ref: ref,
        job: try gitlabCi.getCurrentJob
          .map(handleApi)
          .reduce(Json.GitlabJob.self, dialect.read(_:from:))
          .get(),
        cfg: cfg,
        context: variables
      )
      .map(handleApi)
      .get()
    return true
  }
  public func createReviewPipeline(
    cfg: Configuration
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let review = try gitlabCi.getParentMrState
      .map(handleApi)
      .reduce(Json.GitlabReviewState.self, dialect.read(_:from:))
      .get()
    guard try gitlabCi.parent.pipeline.get() == review.pipeline.id, review.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    _ = try gitlabCi.postParentMrPipelines
      .map(handleApi)
      .get()
    return true
  }
  public func addReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let review = try gitlabCi.getParentMrState
      .map(handleApi)
      .reduce(Json.GitlabReviewState.self, dialect.read(_:from:))
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
    _ = try gitlabCi
      .putMrState(parameters: .init(addLabels: labels.joined(separator: ",")))
      .map(handleApi)
      .reduce(Json.GitlabReviewState.self, dialect.read(_:from:))
      .get()
    logMessage(.init(message: "Labels added"))
    return true
  }
  public func affectParentJob(
    configuration cfg: Configuration,
    name: String,
    action: GitlabCi.HandleApi.JobAction
  ) throws -> Bool {
    let gitlabCi = try cfg.controls.gitlabCi.get()
    let review = try gitlabCi.getParentMrState
      .map(handleApi)
      .reduce(Json.GitlabReviewState.self, dialect.read(_:from:))
      .get()
    guard try gitlabCi.parent.pipeline.get() == review.pipeline.id, review.state == "opened" else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    let job = try gitlabCi
      .getParentPipelineJobs(action: action)
      .map(handleApi)
      .reduce([Json.GitlabJob].self, dialect.read(_:from:))
      .get()
      .first { $0.name == name }
      .or { throw Thrown("Job \(name) not found") }
    _ = try gitlabCi
      .postJobsAction(job: job.id, action: action)
      .map(handleApi)
      .get()
    return true
  }
}
