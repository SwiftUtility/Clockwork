import Foundation
import Facility
import FacilityAutomates
public extension GitlabCi {
  func getPipeline(
    pipeline: UInt
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/pipelines/\(pipeline)",
    headers: [botAuth.get()]
  )]))}
  var getParentMrState: Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/merge_requests/\(parent.review.get())?include_rebase_in_progress=true",
    headers: [botAuth.get()]
  )]))}
  var getParentMrAwarders: Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/merge_requests/\(parent.review.get())/award_emoji",
    headers: [botAuth.get()]
  )]))}
  var postParentMrPipelines: Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/merge_requests/\(parent.review.get())/pipelines",
    method: "POST",
    headers: [botAuth.get()]
  )]))}
  func postParentMrAward(
    award: String
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/merge_requests/\(parent.review.get())/award_emoji?name=\(award)",
    method: "POST",
    headers: [botAuth.get()]
  )]))}
  func putMrState(
    parameters: HandleApi.PutMrState
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/merge_requests/\(parent.review.get())",
    method: "PUT",
    data: parameters.curl.get(),
    headers: [botAuth.get(), Json.contentType]
  )]))}
  func putMrMerge(
    parameters: HandleApi.PutMrMerge
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/merge_requests/\(parent.review.get())/merge",
    method: "PUT",
    checkHttp: false,
    data: parameters.curl.get(),
    headers: [botAuth.get(), Json.contentType]
  )]))}
  func postTriggerPipeline(
    ref: String,
    job: Json.GitlabJob,
    cfg: Configuration,
    context: [String: String]
  ) -> Lossy<HandleApi> { .init(.init(tasks: [.makeCurl(
    url: "\(url)/trigger/pipeline",
    method: "POST",
    form: [
      "token=\(jobToken)",
      "ref=\(ref)",
      "variables[\(trigger.pipeline)]=\(job.pipeline.id)",
      "variables[\(trigger.profile)]=\(cfg.profile.profile.path)",
    ] + review
      .map { "variables[\(trigger.review)]=\($0)" }
      .makeArray()
    + context
      .map { "variables[\($0.key)]=\($0.value)" }
  )]))}
  func postMergeRequests(
    parameters: HandleApi.PostMergeRequests
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/merge_requests",
    method: "POST",
    data: parameters.curl.get(),
    headers: [botAuth.get(), Json.contentType]
  )]))}
  func listShaMergeRequests(
    sha: Git.Sha
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/repository/commits/\(sha)/merge_requests",
    headers: [botAuth.get()]
  )]))}
  func getParentPipelineJobs(
    action: HandleApi.JobAction,
    page: Int = 0
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/pipelines/\(parent.pipeline.get())/jobs?\(action.jobsQuery(page: page))",
    headers: [botAuth.get()]
  )]))}
  var getCurrentJob: Lossy<HandleApi> { .init(.init(tasks: [.makeCurl(
    url: "\(api)/job",
    headers: ["Authorization: Bearer \(jobToken)"]
  )]))}
  func postJobsAction(
    job: UInt,
    action: HandleApi.JobAction
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/jobs/\(job)/\(action.rawValue)",
    headers: [botAuth.get()]
  )]))}
  func postTags(
    parameters: HandleApi.PostTags
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/repository/tags?\(parameters.query())",
    method: "POST",
    headers: [botAuth.get()]
  )]))}
  func postBranches(
    name: String,
    ref: String
  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
    url: "\(url)/repository/branches?branch=\(name)&ref=\(ref)",
    method: "POST",
    headers: [botAuth.get()]
  )]))}
  struct HandleApi: ProcessHandler {
    public var tasks: [PipeTask]
    public func handle(data: Data) throws -> Reply {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return try decoder.decode(Reply.self, from: data)
    }
    public typealias Reply = AnyCodable
    public struct PutMrState: Encodable {
      public var targetBranch: String?
      public var title: String?
      public var addLabels: String?
      public var removeLabels: String?
      public var stateEvent: String?
      public init(
        targetBranch: String? = nil,
        title: String? = nil,
        addLabels: String? = nil,
        removeLabels: String? = nil,
        stateEvent: String? = nil
      ) {
        self.targetBranch = targetBranch
        self.title = title
        self.addLabels = addLabels
        self.removeLabels = removeLabels
        self.stateEvent = stateEvent
      }
    }
    public struct PutMrMerge: Encodable {
      public var mergeCommitMessage: String?
      public var squashCommitMessage: String?
      public var squash: Bool?
      public var shouldRemoveSourceBranch: Bool?
      public var mergeWhenPipelineSucceeds: Bool?
      public var sha: String?
      public init(
        mergeCommitMessage: String? = nil,
        squashCommitMessage: String? = nil,
        squash: Bool? = nil,
        shouldRemoveSourceBranch: Bool? = nil,
        mergeWhenPipelineSucceeds: Bool? = nil,
        sha: Git.Sha? = nil
      ) {
        self.mergeCommitMessage = mergeCommitMessage
        self.squashCommitMessage = squashCommitMessage
        self.squash = squash
        self.shouldRemoveSourceBranch = shouldRemoveSourceBranch
        self.mergeWhenPipelineSucceeds = mergeWhenPipelineSucceeds
        self.sha = sha?.value
      }
    }
    public struct PostMergeRequests: Encodable {
      public var sourceBranch: String
      public var targetBranch: String
      public var title: String
      public init(
        sourceBranch: String,
        targetBranch: String,
        title: String
      ) {
        self.sourceBranch = sourceBranch
        self.targetBranch = targetBranch
        self.title = title
      }
    }
    public enum JobAction: String {
      case play = "play"
      case cancel = "cancel"
      case retry = "retry"
      func jobsQuery(page: Int) -> String {
        var result: [String] = ["include_retried=true", "page=\(page)", "per_page=100"]
        switch self {
        case .play: result += ["scope=manual"]
        case .cancel: result += ["scope[]=pending", "scope[]=running", "scope[]=created"]
        case .retry: result += ["scope[]=failed", "scope[]=canceled", "scope[]=success"]
        }
        return result.joined(separator: "&")
      }
    }
    public struct PostTags {
      public var name: String
      public var ref: String
      public var message: String
      public init(name: String, ref: String, message: String) {
        self.name = name
        self.ref = ref
        self.message = message
      }
      func query() throws -> String {
        let message = try message
          .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
          .or { throw Thrown("Invalid tag annotation message") }
        return ["tag_name=\(name)", "ref=\(ref)", "message=\(message)"]
          .joined(separator: "&")
      }
    }
  }
//  struct GetPipeline: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      pipelineId: UInt,
//      auth: String
//    ) {
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/pipelines/\(pipelineId)",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = Json.GitlabPipeline
//  }
//  struct PostTags: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      auth: String,
//      name: String,
//      ref: String,
//      message: String
//    ) {
//      let query = "tag_name=\(name)&ref=\(ref)&message=\(message)"
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/repository/tags?\(query)",
//        method: "POST",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = AnyCodable
//  }
//  struct PostBranches: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      name: String,
//      ref: String,
//      auth: String
//    ) {
//      let query = "branch=\(name)&ref=\(ref)"
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/repository/branches?\(query)",
//        method: "POST",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = AnyCodable
//  }
//  struct GetMrState: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      mergeIid: UInt,
//      auth: String
//    ) {
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)?include_rebase_in_progress=true",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = Json.GitlabReviewState
//  }
//  struct PutMrState: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      mergeIid: UInt,
//      auth: String,
//      parameters: Parameters
//    ) throws {
//      let encoder = JSONEncoder()
//      encoder.keyEncodingStrategy = .convertToSnakeCase
//      self.tasks = try [.makeCurl(
//        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)",
//        method: "PUT",
//        data: Id(parameters)
//          .map(encoder.encode(_:))
//          .map(String.make(utf8:))
//          .get(),
//        headers: [auth, Json.contentType]
//      )]
//    }
//    public typealias Reply = Json.GitlabReviewState
//  }
//  struct GetMrAwarders: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      mergeIid: UInt,
//      auth: String
//    ) {
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/award_emoji",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = [Json.GitlabAward]
//  }
//  struct PostMrPipelines: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      mergeIid: UInt,
//      auth: String
//    ) {
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/pipelines",
//        method: "POST",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = AnyCodable
//  }
//  struct PostMrAward: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      mergeIid: UInt,
//      auth: String,
//      award: String
//    ) {
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/award_emoji?name=\(award)",
//        method: "POST",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = Json.GitlabAward
//  }
//  struct PutMrMerge: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      mergeIid: UInt,
//      auth: String,
//      parameters: Parameters
//    ) throws {
//      let encoder = JSONEncoder()
//      encoder.keyEncodingStrategy = .convertToSnakeCase
//      self.tasks = try [.makeCurl(
//        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/merge",
//        method: "PUT",
//        checkHttp: false,
//        data: Id(parameters)
//          .map(encoder.encode(_:))
//          .map(String.make(utf8:))
//          .get(),
//        headers: [auth, Json.contentType]
//      )]
//    }
//    public typealias Reply = AnyCodable
//  }
//  struct PutMrRebase: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      mergeIid: UInt,
//      auth: String
//    ) {
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/rebase",
//        method: "PUT",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = Json.GitlabRebase
//  }
//  struct PostTriggerPipeline: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      token: String,
//      ref: String,
//      variables: [String: String]
//    ) {
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/trigger/pipeline",
//        method: "POST",
//        form: ["token=\(token)", "ref=\(ref)"] + variables
//          .map { "variables[\($0.key)]=\($0.value)" }
//      )]
//    }
//    public typealias Reply = AnyCodable
//  }
//  struct ListShaMergeRequests: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      auth: String,
//      sha: String
//    ) {
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/repository/commits/\(sha)/merge_requests",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = [Json.GitlabCommitMergeRequest]
//  }
//  struct PostMergeRequests: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      auth: String,
//      parameters: Parameters
//    ) throws {
//      let encoder = JSONEncoder()
//      encoder.keyEncodingStrategy = .convertToSnakeCase
//      self.tasks = try [.makeCurl(
//        url: "\(api)/projects/\(project)/merge_requests",
//        method: "POST",
//        data: Id(parameters)
//          .map(encoder.encode(_:))
//          .map(String.make(utf8:))
//          .get(),
//        headers: [auth, Json.contentType]
//      )]
//    }
//    public typealias Reply = AnyCodable
//  }
//  struct GetPipelineJobs: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      auth: String,
//      pipeline: UInt,
//      scope: String?,
//      includeRetried: Bool?,
//      page: Int?,
//      perPage: Int?
//    ) throws {
//      var params: [String] = []
//      if let scope = scope { params.append("scope=\(scope)") }
//      if let includeRetried = includeRetried { params.append("include_retried=\(includeRetried)") }
//      if let page = page { params.append("page=\(page)") }
//      if let perPage = perPage { params.append("per_page=\(perPage)") }
//      let query = params.isEmpty
//        .then("?" + params.joined(separator: "&")).or("")
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/pipelines/\(pipeline)/jobs\(query)",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = [Json.GitlabJob]
//  }
//  struct GetCurrentJob: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(api: String, auth: String) throws {
//      self.tasks = [.makeCurl(
//        url: "\(api)/job",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = Json.GitlabJob
//  }
//  struct PostJobsAction: ProcessGitlabCiApi {
//    public var tasks: [PipeTask]
//    public init(
//      api: String,
//      project: String,
//      auth: String,
//      job: UInt,
//      action: JobAction
//    ) throws {
//      self.tasks = [.makeCurl(
//        url: "\(api)/projects/\(project)/jobs/\(job)/\(action.rawValue)",
//        headers: [auth]
//      )]
//    }
//    public typealias Reply = AnyCodable
//  }
}
extension Encodable {
  var curl: Lossy<String> {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return Lossy(self)
      .map(encoder.encode(_:))
      .map(String.make(utf8:))
  }
}
