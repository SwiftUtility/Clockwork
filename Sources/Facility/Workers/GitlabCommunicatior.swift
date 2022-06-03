import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabCommunicatior {
  let postTriggerPipeline: Try.Reply<Gitlab.PostTriggerPipeline>
  let getReviewState: Try.Reply<Gitlab.GetMrState>
  let postPipelines: Try.Reply<Gitlab.PostMrPipelines>
  let putState: Try.Reply<Gitlab.PutMrState>
  let getPipelineJobs: Try.Reply<Gitlab.GetPipelineJobs>
  let postJobsAction: Try.Reply<Gitlab.PostJobsAction>
  let resolveGitlab: Try.Reply<ResolveGitlab>
  let logMessage: Act.Reply<LogMessage>
  public init(
    postTriggerPipeline: @escaping Try.Reply<Gitlab.PostTriggerPipeline>,
    getReviewState: @escaping Try.Reply<Gitlab.GetMrState>,
    postPipelines: @escaping Try.Reply<Gitlab.PostMrPipelines>,
    putState: @escaping Try.Reply<Gitlab.PutMrState>,
    getPipelineJobs: @escaping Try.Reply<Gitlab.GetPipelineJobs>,
    postJobsAction: @escaping Try.Reply<Gitlab.PostJobsAction>,
    resolveGitlab: @escaping Try.Reply<ResolveGitlab>,
    logMessage: @escaping Act.Reply<LogMessage>
  ) {
    self.postTriggerPipeline = postTriggerPipeline
    self.getReviewState = getReviewState
    self.postPipelines = postPipelines
    self.putState = putState
    self.getPipelineJobs = getPipelineJobs
    self.postJobsAction = postJobsAction
    self.resolveGitlab = resolveGitlab
    self.logMessage = logMessage
  }
  public func triggerTargetPipeline(
    cfg: Configuration,
    ref: String,
    context: [String]
  ) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    var variables = try gitlab.makeTriggererVariables(cfg: cfg)
    for variable in context {
      let index = try variable.firstIndex(of: "=")
        .or { throw Thrown("wrong argument format \(variable)") }
      let key = variable[variable.startIndex..<index]
      let value = variable[index..<variable.endIndex].dropFirst()
      variables[.init(key)] = .init(value)
    }
    _ = try postTriggerPipeline(gitlab.postTriggerPipeline(
      ref: ref,
      variables: variables
    ))
    return true
  }
  public func addReviewLabels(
    cfg: Configuration,
    labels: [String]
  ) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let state = try getReviewState(gitlab.getParentMrState())
    guard
      case state.pipeline.id? = gitlab.triggererPipeline,
      state.state == "opened"
    else {
      logMessage(.init(message: "Pipeline outdated"))
      return false
    }
    let labels = Set(labels).subtracting(.init(state.labels))
    guard !labels.isEmpty else {
      logMessage(.init(message: "No new labels"))
      return true
    }
    _ = try putState(gitlab.putMrState(parameters: .init(
      addLabels: labels.joined(separator: ",")
    )))
    logMessage(.init(message: "Labels added"))
    _ = try postPipelines(gitlab.postParentMrPipelines())
    return true
  }
  public func affectParentJob(
    configuration cfg: Configuration,
    name: String,
    action: Gitlab.JobAction
  ) throws -> Bool {
    let gitlab = try resolveGitlab(.init(cfg: cfg))
    let job = try getPipelineJobs(gitlab.getParentPipelineJobs(action: action))
      .first { $0.name == name }
      .or { throw Thrown("Job \(name) not found") }
    _ = try postJobsAction(gitlab.postJobsAction(job: job.id, action: action))
    return true
  }
}
