import Foundation
import Facility
public struct GitlabCi {
  public var env: Env
  public let job: Json.GitlabJob
  public var trigger: Yaml.Gitlab.Trigger
  public var protected: Lossy<Protected>
  public var info: Info { .init(
    bot: try? protected.get().user.username,
    url: job.webUrl
      .components(separatedBy: "/-/")
      .first,
    job: job,
    mr: try? job.review.get()
  )}
  public func matches(build: Production.Build) -> Bool {
    guard case .branch(let value) = build else { return false }
    return value.sha == job.pipeline.sha && value.branch == job.pipeline.ref
  }
  public static func make(
    trigger: Yaml.Gitlab.Trigger,
    env: Env,
    job: Json.GitlabJob,
    protected: Lossy<Protected>
  ) -> Self { .init(
    env: env,
    job: job,
    trigger: trigger,
    protected: protected
  )}
  public struct Parent {
    public let job: UInt
    public let profile: Files.Relative
  }
  public struct Protected {
    public let auth: String
    public let push: String
    public let user: Json.GitlabUser
    public var project: String
    public static func make(
      token: Lossy<String>,
      env: Lossy<Env>,
      job: Lossy<Json.GitlabJob>,
      user: Lossy<Json.GitlabUser>
    ) throws -> Self {
      let env = try env.get()
      guard env.isProtected else { throw Thrown("Not protected ref pipeline") }
      let token = try token.get()
      let user = try user.get()
      let job = try job.get()
      return .init(
      auth: "Authorization: Bearer \(token)",
      push: env.push(user: user.username, pass: token),
      user: user,
      project: "\(env.api)/projects/\(job.pipeline.projectId)"
    )}
  }
  public struct Setup {
    public let api: String
    public let host: String
    public let port: String
    public let path: String
    public let scheme: String
    public let token: String
    public let isProtected: Bool

  }
  public struct Env {
    public let api: String
    public let host: String
    public let port: String
    public let path: String
    public let scheme: String
    public let token: String
    public let isProtected: Bool
    public let parent: Lossy<Parent>
    func push(user: String, pass: String) -> String {
      "\(scheme)://\(user):\(pass)@\(host):\(port)/\(path).git"
    }
    public var getJob: Lossy<Execute> {
      return .init(.makeCurl(
        url: "\(api)/job",
        headers: ["Authorization: Bearer \(token)"]
      ))
    }
    public func getTokenUser(token: String) -> Lossy<Execute> { .init(.makeCurl(
      url: "\(api)/user",
      headers: ["Authorization: Bearer \(token)"]
    ))}
    public static func make(env: [String: String], trigger: Yaml.Gitlab.Trigger) throws -> Self {
      guard "true" == env["GITLAB_CI"] else { throw Thrown("Not in GitlabCI context") }
      return try .init(
        api: "CI_API_V4_URL".get(env: env),
        host: "CI_SERVER_HOST".get(env: env),
        port: "CI_SERVER_PORT".get(env: env),
        path: "CI_PROJECT_PATH".get(env: env),
        scheme: "CI_SERVER_PROTOCOL".get(env: env),
        token: "CI_JOB_TOKEN".get(env: env),
        isProtected: env["CI_COMMIT_REF_PROTECTED"] == "true",
        parent: .init(try .init(
          job: trigger.jobId.get(env: env).getUInt(),
          profile: .init(value: trigger.profile.get(env: env))
        ))
      )
    }
  }
  public struct Info: Encodable {
    public var bot: String?
    public var url: String?
    public var job: Json.GitlabJob
    public var mr: UInt?
  }
}
public extension GitlabCi {
  func getJob(
    id: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/jobs/\(id)",
    headers: [protected.get().auth]
  ))}
  var getProject: Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)",
    headers: [protected.get().auth]
  ))}
  func getPipeline(
    pipeline: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/pipelines/\(pipeline)",
    headers: [protected.get().auth]
  ))}
  func getMrState(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/merge_requests/\(review)?include_rebase_in_progress=true",
    headers: [protected.get().auth]
  ))}
  func getMrAwarders(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/merge_requests/\(review)/award_emoji",
    headers: [protected.get().auth]
  ))}
  func postMrPipelines(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/merge_requests/\(review)/pipelines",
    method: "POST",
    headers: [protected.get().auth]
  ))}
  func postMrAward(
    review: UInt,
    award: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/merge_requests/\(review)/award_emoji",
    method: "POST",
    form: ["name=\(award)"],
    headers: [protected.get().auth]
  ))}
  func putMrState(
    parameters: PutMrState,
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/merge_requests/\(review)",
    method: "PUT",
    data: parameters.curl.get(),
    headers: [protected.get().auth, Json.contentType]
  ))}
  func putMrMerge(
    parameters: PutMrMerge,
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/merge_requests/\(review)/merge",
    method: "PUT",
    checkHttp: false,
    data: parameters.curl.get(),
    headers: [protected.get().auth, Json.contentType]
  ))}
  func postTriggerPipeline(
    cfg: Configuration,
    ref: String,
    variables: [String: String]
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/trigger/pipeline",
    method: "POST",
    form: [
      "token=\(env.token)",
      "ref=\(ref)",
    ] + variables.compactMap { pair in pair.value
      .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
      .map { "variables[\(pair.key)]=\($0)" }
    }
  ))}
  func postMergeRequests(
    parameters: PostMergeRequests
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/merge_requests",
    method: "POST",
    data: parameters.curl.get(),
    headers: [protected.get().auth, Json.contentType]
  ))}
  func listShaMergeRequests(
    sha: Git.Sha
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/repository/commits/\(sha.value)/merge_requests",
    headers: [protected.get().auth]
  ))}
  func getJobs(
    action: JobAction,
    pipeline: UInt,
    page: Int,
    count: Int
  ) -> Lossy<Execute> {
    let query = [
      "include_retried=true",
      "page=\(page)",
      "per_page=\(count)",
    ] + action.scope.map { "scope[]=\($0)" }
    return .init(try .makeCurl(
        url: "\(protected.get().project)/pipelines/\(pipeline)/jobs?\(query.joined(separator: "&"))",
      headers: [protected.get().auth]
    ))
  }
  func postJobsAction(
    job: UInt,
    action: JobAction
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/jobs/\(job)/\(action.rawValue)",
    method: "POST",
    headers: [protected.get().auth]
  ))}
  func postTags(
    name: String,
    ref: String,
    message: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/repository/tags",
    method: "POST",
    form: [
      "tag_name=\(name)",
      "ref=\(ref)",
      "message=\(message)",
    ],
    headers: [protected.get().auth]
  ))}
  func postBranches(
    name: String,
    ref: String
  ) -> Lossy<Execute> {
    guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    else { return .error(MayDay("addingPercentEncoding failed")) }
    return .init(try .makeCurl(
        url: "\(protected.get().project)/repository/branches",
      method: "POST",
      form: [
        "branch=\(name)",
        "ref=\(ref)",
      ],
      headers: [protected.get().auth]
    ))
  }
  func deleteBranch(name: String) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/repository/branches/\(name)",
    method: "DELETE",
    headers: [protected.get().auth]
  ))}
  func getBranches(page: Int, count: Int) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/repository/branches?page=\(page)&per_page=\(count)",
    headers: [protected.get().auth]
  ))}
  func getBranch(name: String) -> Lossy<Execute> { .init(try .makeCurl(
    url: "\(protected.get().project)/repository/branches/\(name)",
    headers: [protected.get().auth]
  ))}
  struct PutMrState: Encodable {
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
  struct PutMrMerge: Encodable {
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
  struct PostMergeRequests: Encodable {
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
  enum JobAction: String {
    case play = "play"
    case cancel = "cancel"
    case retry = "retry"
    var scope: [String] {
      switch self {
      case .play: return ["manual"]
      case .cancel: return ["pending", "running", "created"]
      case .retry: return ["failed", "canceled", "success"]
      }
    }
  }
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
