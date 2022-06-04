import Foundation
import Facility
import FacilityAutomates
public protocol ProcessGitlabCiApi: ProcessHandler {}
extension ProcessGitlabCiApi where Reply: Decodable {
  public func handle(data: Data) throws -> Reply {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(Reply.self, from: data)
  }
}
public extension Gitlab {
  func getParentPipeline() throws -> GetPipeline { try .init(
    api: api,
    project: project,
    pipelineId: triggererPipeline
      .or { throw Thrown("No env \(parentPipeline)") },
    auth: "Authorization: Bearer \(makeBotToken())"
  )}
  func getParentMrState() throws -> GetMrState { try .init(
    api: api,
    project: project,
    mergeIid: triggererReview
      .or { throw Thrown("No env \(parentReview)") },
    auth: "Authorization: Bearer \(makeBotToken())"
  )}
  func getParentMrAwarders() throws -> GetMrAwarders { try .init(
    api: api,
    project: project,
    mergeIid: triggererReview
      .or { throw Thrown("No env \(parentReview)") },
    auth: "Authorization: Bearer \(makeBotToken())"
  )}
  func postParentMrPipelines() throws -> PostMrPipelines { try .init(
    api: api,
    project: project,
    mergeIid: triggererReview
      .or { throw Thrown("No env \(parentReview)") },
    auth: "Authorization: Bearer \(makeBotToken())"
  )}
  func putParentMrRebase() throws -> PutMrRebase { try .init(
    api: api,
    project: project,
    mergeIid: triggererReview
      .or { throw Thrown("No env \(parentReview)") },
    auth: "Authorization: Bearer \(makeBotToken())"
  )}
  func postParentMrAward(award: String) throws -> PostMrAward { try .init(
    api: api,
    project: project,
    mergeIid: triggererReview
      .or { throw Thrown("No env \(parentReview)") },
    auth: "Authorization: Bearer \(makeBotToken())",
    award: award
  )}
  func putMrState(parameters: PutMrState.Parameters) throws -> PutMrState { try .init(
    api: api,
    project: project,
    mergeIid: triggererReview
      .or { throw Thrown("No env \(parentReview)") },
    auth: "Authorization: Bearer \(makeBotToken())",
    parameters: parameters
  )}
  func putMrMerge(parameters: PutMrMerge.Parameters) throws -> PutMrMerge { try .init(
    api: api,
    project: project,
    mergeIid: triggererReview
      .or { throw Thrown("No env \(parentReview)") },
    auth: "Authorization: Bearer \(makeBotToken())",
    parameters: parameters
  )}
  func postTriggerPipeline(
    ref: String,
    variables: [String : String]
  ) -> PostTriggerPipeline { .init(
    api: api,
    project: project,
    token: jobToken,
    ref: ref,
    variables: variables
  )}
  func postMergeRequests(
    parameters: PostMergeRequests.Parameters
  ) throws -> PostMergeRequests { try .init(
    api: api,
    project: project,
    auth: "Authorization: Bearer \(makeBotToken())",
    parameters: parameters
  )}
  func listShaMergeRequests(sha: Git.Sha) throws -> ListShaMergeRequests { try .init(
    api: api,
    project: project,
    auth: "Authorization: Bearer \(makeBotToken())",
    sha: sha.value
  )}
  func getParentPipelineJobs(action: JobAction, page: Int = 1) throws -> GetPipelineJobs { try .init(
    api: api,
    project: project,
    auth: "Authorization: Bearer \(makeBotToken())",
    pipeline: triggererPipeline
      .or { throw Thrown("No env \(parentPipeline)") },
    scope: action.scope,
    includeRetried: true,
    page: page,
    perPage: 100
  )}
  func postJobsAction(job: UInt, action: JobAction) throws -> PostJobsAction { try .init(
    api: api,
    project: project,
    auth: "Authorization: Bearer \(makeBotToken())",
    job: job,
    action: action
  )}
  struct GetPipeline: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      pipelineId: UInt,
      auth: String
    ) {
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/pipelines/\(pipelineId)",
        headers: [auth]
      )]
    }
    public typealias Reply = Json.GitlabPipeline
  }
  struct GetMrState: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      mergeIid: UInt,
      auth: String
    ) {
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)?include_rebase_in_progress=true",
        headers: [auth]
      )]
    }
    public typealias Reply = Json.GitlabReviewState
  }
  struct PutMrState: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      mergeIid: UInt,
      auth: String,
      parameters: Parameters
    ) throws {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      self.tasks = try [.makeCurl(
        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)",
        method: "PUT",
        data: Id(parameters)
          .map(encoder.encode(_:))
          .map(String.make(utf8:))
          .get(),
        headers: [auth, Gitlab.json]
      )]
    }
    public typealias Reply = Json.GitlabReviewState
    public struct Parameters: Encodable {
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
  }
  struct GetMrAwarders: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      mergeIid: UInt,
      auth: String
    ) {
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/award_emoji",
        headers: [auth]
      )]
    }
    public typealias Reply = [Json.GitlabAward]
  }
  struct PostMrPipelines: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      mergeIid: UInt,
      auth: String
    ) {
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/pipelines",
        method: "POST",
        headers: [auth]
      )]
    }
    public typealias Reply = AnyCodable
  }
  struct PostMrAward: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      mergeIid: UInt,
      auth: String,
      award: String
    ) {
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/award_emoji?name=\(award)",
        method: "POST",
        headers: [auth]
      )]
    }
    public typealias Reply = Json.GitlabAward
  }
  struct PutMrMerge: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      mergeIid: UInt,
      auth: String,
      parameters: Parameters
    ) throws {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      self.tasks = try [.makeCurl(
        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/merge",
        method: "PUT",
        checkHttp: false,
        data: Id(parameters)
          .map(encoder.encode(_:))
          .map(String.make(utf8:))
          .get(),
        headers: [auth, Gitlab.json]
      )]
    }
    public typealias Reply = AnyCodable
    public struct Parameters: Encodable {
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
  }
  struct PutMrRebase: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      mergeIid: UInt,
      auth: String
    ) {
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/merge_requests/\(mergeIid)/rebase",
        method: "PUT",
        headers: [auth]
      )]
    }
    public typealias Reply = Json.GitlabRebase
  }
  struct PostTriggerPipeline: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      token: String,
      ref: String,
      variables: [String: String]
    ) {
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/trigger/pipeline",
        method: "POST",
        form: ["token=\(token)", "ref=\(ref)"] + variables
          .map { "variables[\($0.key)]=\($0.value)" }
      )]
    }
    public typealias Reply = AnyCodable
  }
  struct ListShaMergeRequests: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      auth: String,
      sha: String
    ) {
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/repository/commits/\(sha)/merge_requests",
        headers: [auth]
      )]
    }
    public typealias Reply = [Json.GitlabCommitMergeRequest]
  }
  struct PostMergeRequests: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      auth: String,
      parameters: Parameters
    ) throws {
      let encoder = JSONEncoder()
      encoder.keyEncodingStrategy = .convertToSnakeCase
      self.tasks = try [.makeCurl(
        url: "\(api)/projects/\(project)/merge_requests",
        method: "POST",
        data: Id(parameters)
          .map(encoder.encode(_:))
          .map(String.make(utf8:))
          .get(),
        headers: [auth, Gitlab.json]
      )]
    }
    public typealias Reply = AnyCodable
    public struct Parameters: Encodable {
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
  }
  struct GetPipelineJobs: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      auth: String,
      pipeline: UInt,
      scope: String?,
      includeRetried: Bool?,
      page: Int?,
      perPage: Int?
    ) throws {
      var params: [String] = []
      if let scope = scope { params.append("scope=\(scope)") }
      if let includeRetried = includeRetried { params.append("include_retried=\(includeRetried)") }
      if let page = page { params.append("page=\(page)") }
      if let perPage = perPage { params.append("per_page=\(perPage)") }
      let query = params.isEmpty
        .then("?" + params.joined(separator: "&")).or("")
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/pipelines/\(pipeline)/jobs\(query)",
        headers: [auth]
      )]
    }
    public typealias Reply = [Json.GitlabPilelineJob]
  }
  struct PostJobsAction: ProcessGitlabCiApi {
    public var tasks: [PipeTask]
    public init(
      api: String,
      project: String,
      auth: String,
      job: UInt,
      action: JobAction
    ) throws {
      self.tasks = [.makeCurl(
        url: "\(api)/projects/\(project)/jobs/\(job)/\(action.rawValue)",
        headers: [auth]
      )]
    }
    public typealias Reply = AnyCodable
  }
}
