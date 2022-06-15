import Foundation
import Facility
import FacilityAutomates
//public extension GitlabCi {
//  func getPipeline(
//    pipeline: UInt
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/pipelines/\(pipeline)",
//    headers: [botAuth.get()]
//  )]))}
//  var getParentMrState: Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/merge_requests/\(parent.review.get())?include_rebase_in_progress=true",
//    headers: [botAuth.get()]
//  )]))}
//  var getParentMrAwarders: Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/merge_requests/\(parent.review.get())/award_emoji",
//    headers: [botAuth.get()]
//  )]))}
//  var postParentMrPipelines: Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/merge_requests/\(parent.review.get())/pipelines",
//    method: "POST",
//    headers: [botAuth.get()]
//  )]))}
//  func postParentMrAward(
//    award: String
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/merge_requests/\(parent.review.get())/award_emoji?name=\(award)",
//    method: "POST",
//    headers: [botAuth.get()]
//  )]))}
//  func putMrState(
//    parameters: HandleApi.PutMrState
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/merge_requests/\(parent.review.get())",
//    method: "PUT",
//    data: parameters.curl.get(),
//    headers: [botAuth.get(), Json.contentType]
//  )]))}
//  func putMrMerge(
//    parameters: HandleApi.PutMrMerge
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/merge_requests/\(parent.review.get())/merge",
//    method: "PUT",
//    checkHttp: false,
//    data: parameters.curl.get(),
//    headers: [botAuth.get(), Json.contentType]
//  )]))}
//  func postTriggerPipeline(
//    ref: String,
//    job: Json.GitlabJob,
//    cfg: Configuration,
//    context: [String: String]
//  ) -> Lossy<HandleApi> { .init(.init(tasks: [.makeCurl(
//    url: "\(url)/trigger/pipeline",
//    method: "POST",
//    form: [
//      "token=\(jobToken)",
//      "ref=\(ref)",
//      "variables[\(trigger.pipeline)]=\(job.pipeline.id)",
//      "variables[\(trigger.profile)]=\(cfg.profile.profile.path)",
//    ] + review
//      .map { "variables[\(trigger.review)]=\($0)" }
//      .makeArray()
//    + context
//      .map { "variables[\($0.key)]=\($0.value)" }
//  )]))}
//  func postMergeRequests(
//    parameters: HandleApi.PostMergeRequests
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/merge_requests",
//    method: "POST",
//    data: parameters.curl.get(),
//    headers: [botAuth.get(), Json.contentType]
//  )]))}
//  func listShaMergeRequests(
//    sha: Git.Sha
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/repository/commits/\(sha)/merge_requests",
//    headers: [botAuth.get()]
//  )]))}
//  func getParentPipelineJobs(
//    action: HandleApi.JobAction,
//    page: Int = 0
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/pipelines/\(parent.pipeline.get())/jobs?\(action.jobsQuery(page: page))",
//    headers: [botAuth.get()]
//  )]))}
//  var getCurrentJob: Lossy<HandleApi> { .init(.init(tasks: [.makeCurl(
//    url: "\(api)/job",
//    headers: ["Authorization: Bearer \(jobToken)"]
//  )]))}
//  func postJobsAction(
//    job: UInt,
//    action: HandleApi.JobAction
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/jobs/\(job)/\(action.rawValue)",
//    headers: [botAuth.get()]
//  )]))}
//  func postTags(
//    parameters: HandleApi.PostTags
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/repository/tags?\(parameters.query())",
//    method: "POST",
//    headers: [botAuth.get()]
//  )]))}
//  func postBranches(
//    name: String,
//    ref: String
//  ) -> Lossy<HandleApi> { .init(try .init(tasks: [.makeCurl(
//    url: "\(url)/repository/branches?branch=\(name)&ref=\(ref)",
//    method: "POST",
//    headers: [botAuth.get()]
//  )]))}
//  struct HandleApi: ProcessHandler {
//    public var tasks: [PipeTask]
//    public func handle(data: Data) throws -> Reply {
//      let decoder = JSONDecoder()
//      decoder.keyDecodingStrategy = .convertFromSnakeCase
//      return try decoder.decode(Reply.self, from: data)
//    }
//    public typealias Reply = AnyCodable
//    public struct PutMrState: Encodable {
//      public var targetBranch: String?
//      public var title: String?
//      public var addLabels: String?
//      public var removeLabels: String?
//      public var stateEvent: String?
//      public init(
//        targetBranch: String? = nil,
//        title: String? = nil,
//        addLabels: String? = nil,
//        removeLabels: String? = nil,
//        stateEvent: String? = nil
//      ) {
//        self.targetBranch = targetBranch
//        self.title = title
//        self.addLabels = addLabels
//        self.removeLabels = removeLabels
//        self.stateEvent = stateEvent
//      }
//    }
//    public struct PutMrMerge: Encodable {
//      public var mergeCommitMessage: String?
//      public var squashCommitMessage: String?
//      public var squash: Bool?
//      public var shouldRemoveSourceBranch: Bool?
//      public var mergeWhenPipelineSucceeds: Bool?
//      public var sha: String?
//      public init(
//        mergeCommitMessage: String? = nil,
//        squashCommitMessage: String? = nil,
//        squash: Bool? = nil,
//        shouldRemoveSourceBranch: Bool? = nil,
//        mergeWhenPipelineSucceeds: Bool? = nil,
//        sha: Git.Sha? = nil
//      ) {
//        self.mergeCommitMessage = mergeCommitMessage
//        self.squashCommitMessage = squashCommitMessage
//        self.squash = squash
//        self.shouldRemoveSourceBranch = shouldRemoveSourceBranch
//        self.mergeWhenPipelineSucceeds = mergeWhenPipelineSucceeds
//        self.sha = sha?.value
//      }
//    }
//    public struct PostMergeRequests: Encodable {
//      public var sourceBranch: String
//      public var targetBranch: String
//      public var title: String
//      public init(
//        sourceBranch: String,
//        targetBranch: String,
//        title: String
//      ) {
//        self.sourceBranch = sourceBranch
//        self.targetBranch = targetBranch
//        self.title = title
//      }
//    }
//    public enum JobAction: String {
//      case play = "play"
//      case cancel = "cancel"
//      case retry = "retry"
//      func jobsQuery(page: Int) -> String {
//        var result: [String] = ["include_retried=true", "page=\(page)", "per_page=100"]
//        switch self {
//        case .play: result += ["scope=manual"]
//        case .cancel: result += ["scope[]=pending", "scope[]=running", "scope[]=created"]
//        case .retry: result += ["scope[]=failed", "scope[]=canceled", "scope[]=success"]
//        }
//        return result.joined(separator: "&")
//      }
//    }
//    public struct PostTags {
//      public var name: String
//      public var ref: String
//      public var message: String
//      public init(name: String, ref: String, message: String) {
//        self.name = name
//        self.ref = ref
//        self.message = message
//      }
//      func query() throws -> String {
//        let message = try message
//          .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
//          .or { throw Thrown("Invalid tag annotation message") }
//        return ["tag_name=\(name)", "ref=\(ref)", "message=\(message)"]
//          .joined(separator: "&")
//      }
//    }
//  }
//}
//extension Encodable {
//  var curl: Lossy<String> {
//    let encoder = JSONEncoder()
//    encoder.keyEncodingStrategy = .convertToSnakeCase
//    return Lossy(self)
//      .map(encoder.encode(_:))
//      .map(String.make(utf8:))
//  }
//}
