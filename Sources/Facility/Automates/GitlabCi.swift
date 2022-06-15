import Foundation
import Facility
public struct GitlabCi {
  public var verbose: Bool
  public var botLogin: String
  public var trigger: Trigger
  public var api: String
  public var project: String
  public var jobToken: String
  public var review: String?
  public var reviewTarget: String?
  public var botAuth: Lossy<String>
  public var pushUrl: Lossy<String>
  public var parent: Parent
  public var url: String { "\(api)/projects/\(project)" }
  public static func make(
    verbose: Bool,
    env: [String: String],
    yaml: Yaml.Controls.GitlabCi,
    apiToken: Lossy<String>,
    pushToken: Lossy<String>
  ) -> Lossy<Self> {
    guard case "true" = env[Self.gitlabci]
    else { return .error(Thrown("Not in GitlabCI context")) }
    let trigger = Trigger(
      pipeline: yaml.trigger.pipeline,
      review: yaml.trigger.review,
      profile: yaml.trigger.profile
    )
    return .init(try .init(
      verbose: verbose,
      botLogin: yaml.bot.login,
      trigger: trigger,
      api: apiV4.get(env: env),
      project: projectId.get(env: env),
      jobToken: jobToken.get(env: env),
      review: env[review],
      reviewTarget: env[reviewTarget],
      botAuth: apiToken
        .map { "Authorization: Bearer " + $0 },
      pushUrl: pushToken
        .map { pushToken in
          let scheme = try scheme.get(env: env)
          let host = try host.get(env: env)
          let port = try port.get(env: env)
          let path = try path.get(env: env)
          return "\(scheme)://\(yaml.bot.login):\(pushToken)@\(host):\(port)/\(path)"
        },
      parent: trigger.makeParent(env: env)
    ))
  }
  public static func makeApiToken(
    env: [String: String],
    yaml: Yaml.Controls.GitlabCi
  ) -> Lossy<Token> {
    guard case "true" = env[Self.protected]
    else { return .error(Thrown("Not in protected pipeline")) }
    return Lossy.value(yaml.bot.apiToken)
      .reduce(curry: Thrown("apiToken not configured"), Optional.or(error:))
      .map(Token.init(yaml:))
  }
  public static func makePushToken(
    env: [String: String],
    yaml: Yaml.Controls.GitlabCi
  ) -> Lossy<Token> {
    guard case "true" = env[Self.protected]
    else { return .error(Thrown("Not in protected pipeline")) }
    return Lossy.value(yaml.bot.pushToken)
      .reduce(curry: Thrown("pushToken not configured"), Optional.or(error:))
      .map(Token.init(yaml:))
  }
  static var gitlabci: String { "GITLAB_CI" }
  static var protected: String { "CI_COMMIT_REF_PROTECTED" }
  static var triggered: String { "CI_PIPELINE_TRIGGERED" }
  static var apiV4: String { "CI_API_V4_URL" }
  static var projectId: String { "CI_PROJECT_ID" }
  static var jobToken: String { "CI_JOB_TOKEN" }
  static var scheme: String { "CI_SERVER_PROTOCOL" }
  static var host: String { "CI_SERVER_HOST" }
  static var port: String { "CI_SERVER_PORT" }
  static var path: String { "CI_PROJECT_PATH" }
  static var review: String { "CI_MERGE_REQUEST_IID" }
  static var reviewTarget: String { "CI_MERGE_REQUEST_TARGET_BRANCH_NAME" }
  public struct Trigger {
    public var pipeline: String
    public var review: String
    public var profile: String
    func makeParent(env: [String: String]) -> Parent {
      guard case "true" = env[GitlabCi.triggered] else { return .init(
        pipeline: .error(Thrown("Not triggered pipeline")),
        review: .error(Thrown("Not triggered pipeline")),
        profile: .error(Thrown("Not triggered pipeline"))
      )}
      return .init(
        pipeline: Lossy(try pipeline.get(env: env))
          .map(UInt.init(_:))
          .reduce(curry: Thrown("Malformed \(pipeline)"), Optional.or(error:)),
        review: Lossy(env[review])
          .reduce(curry: Thrown("Triggered not from review"), Optional.or(error:))
          .map(UInt.init(_:))
          .reduce(curry: Thrown("Malformed \(review)"), Optional.or(error:)),
        profile: Lossy(try .init(value: profile.get(env: env)))
      )
    }
  }
  public struct Parent {
    public var pipeline: Lossy<UInt>
    public var review: Lossy<UInt>
    public var profile: Lossy<Path.Relative>
  }
}
public extension GitlabCi {
  func getPipeline(
    pipeline: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/pipelines/\(pipeline)",
    headers: [botAuth.get()]
  ))}
  var getParentMrState: Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(parent.review.get())?include_rebase_in_progress=true",
    headers: [botAuth.get()]
  ))}
  var getParentMrAwarders: Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(parent.review.get())/award_emoji",
    headers: [botAuth.get()]
  ))}
  var postParentMrPipelines: Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(parent.review.get())/pipelines",
    method: "POST",
    headers: [botAuth.get()]
  ))}
  func postParentMrAward(
    award: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(parent.review.get())/award_emoji?name=\(award)",
    method: "POST",
    headers: [botAuth.get()]
  ))}
  func putMrState(
    parameters: PutMrState
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(parent.review.get())",
    method: "PUT",
    data: parameters.curl.get(),
    headers: [botAuth.get(), Json.contentType]
  ))}
  func putMrMerge(
    parameters: PutMrMerge
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(parent.review.get())/merge",
    method: "PUT",
    checkHttp: false,
    data: parameters.curl.get(),
    headers: [botAuth.get(), Json.contentType]
  ))}
  func postTriggerPipeline(
    ref: String,
    job: Json.GitlabJob,
    cfg: Configuration,
    context: [String: String]
  ) -> Lossy<Execute> { .init(.makeCurl(
    verbose: verbose,
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
  ))}
  func postMergeRequests(
    parameters: PostMergeRequests
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests",
    method: "POST",
    data: parameters.curl.get(),
    headers: [botAuth.get(), Json.contentType]
  ))}
  func listShaMergeRequests(
    sha: Git.Sha
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/repository/commits/\(sha)/merge_requests",
    headers: [botAuth.get()]
  ))}
  func getParentPipelineJobs(
    action: JobAction,
    page: Int = 0
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/pipelines/\(parent.pipeline.get())/jobs?\(action.jobsQuery(page: page))",
    headers: [botAuth.get()]
  ))}
  var getCurrentJob: Lossy<Execute> { .init(.makeCurl(
    verbose: verbose,
    url: "\(api)/job",
    headers: ["Authorization: Bearer \(jobToken)"]
  ))}
  func postJobsAction(
    job: UInt,
    action: JobAction
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/jobs/\(job)/\(action.rawValue)",
    headers: [botAuth.get()]
  ))}
  func postTags(
    parameters: PostTags
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/repository/tags?\(parameters.query())",
    method: "POST",
    headers: [botAuth.get()]
  ))}
  func postBranches(
    name: String,
    ref: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/repository/branches?branch=\(name)&ref=\(ref)",
    method: "POST",
    headers: [botAuth.get()]
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
  struct PostTags {
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
extension Encodable {
  var curl: Lossy<String> {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    return Lossy(self)
      .map(encoder.encode(_:))
      .map(String.make(utf8:))
  }
}
