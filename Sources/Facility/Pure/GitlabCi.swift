import Foundation
import Facility
public struct GitlabCi {
  public var verbose: Bool
  public var botLogin: String
  public var trigger: Trigger
  public var api: String
  public var project: String
  public var config: String
  public var job: Json.GitlabJob
  public var jobToken: String
  public var botAuth: Lossy<String>
  public var pushUrl: Lossy<String>
  public var parent: Lossy<Parent>
  public var url: String { "\(api)/projects/\(project)" }
  public var info: Info { .init(
    bot: botLogin,
    url: job.webUrl
      .components(separatedBy: "/-/")
      .first,
    job: job,
    mr: try? job.review.get()
  )}
  public static func make(
    verbose: Bool,
    env: [String: String],
    yaml: Yaml.Controls.GitlabCi,
    job: Lossy<Json.GitlabJob>,
    apiToken: Lossy<String>,
    pushToken: Lossy<String>
  ) -> Lossy<Self> {
    guard case "true" = env[Self.gitlabci]
    else { return .error(Thrown("Not in GitlabCI context")) }
    return .init(try .init(
      verbose: verbose,
      botLogin: yaml.bot.login,
      trigger: .init(
        job: yaml.trigger.job,
        name: yaml.trigger.name,
        profile: yaml.trigger.profile,
        pipeline: yaml.trigger.pipeline
      ),
      api: apiV4.get(env: env),
      project: projectId.get(env: env),
      config: config.get(env: env),
      job: job.get(),
      jobToken: jobToken.get(env: env),
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
      parent: Self.makeParent(env: env, yaml: yaml)
    ))
  }
  public static func makeApiToken(
    env: [String: String],
    yaml: Yaml.Controls.GitlabCi
  ) -> Lossy<Configuration.Secret> {
    guard case "true" = env[Self.protected]
    else { return .error(Thrown("Not in protected pipeline")) }
    return Lossy.value(yaml.bot.apiToken)
      .reduce(Thrown("apiToken not configured"), Optional.get(or:value:))
      .map(Configuration.Secret.make(yaml:))
  }
  public static func makePushToken(
    env: [String: String],
    yaml: Yaml.Controls.GitlabCi
  ) -> Lossy<Configuration.Secret> {
    guard case "true" = env[Self.protected]
    else { return .error(Thrown("Not in protected pipeline")) }
    return Lossy.value(yaml.bot.pushToken)
      .reduce(Thrown("pushToken not configured"), Optional.get(or:value:))
      .map(Configuration.Secret.make(yaml:))
  }
  public static func makeParent(
    env: [String: String],
    yaml: Yaml.Controls.GitlabCi
  ) -> Lossy<Parent> {
    guard case "true" = env[GitlabCi.protected]
    else { return .error(Thrown("Not in protected pipeline")) }
    return .init(try .init(
      job: yaml.trigger.job.get(env: env).getUInt(),
      profile: .init(value: yaml.trigger.profile.get(env: env))
    ))
  }
  static var gitlabci: String { "GITLAB_CI" }
  static var protected: String { "CI_COMMIT_REF_PROTECTED" }
  static var apiV4: String { "CI_API_V4_URL" }
  static var projectId: String { "CI_PROJECT_ID" }
  static var jobToken: String { "CI_JOB_TOKEN" }
  static var scheme: String { "CI_SERVER_PROTOCOL" }
  static var host: String { "CI_SERVER_HOST" }
  static var port: String { "CI_SERVER_PORT" }
  static var path: String { "CI_PROJECT_PATH" }
  static var config: String { "CI_CONFIG_PATH" }
  public struct Trigger {
    public var job: String
    public var name: String
    public var profile: String
    public var pipeline: String
  }
  public struct Parent {
    public var job: UInt
    public var profile: Files.Relative
  }
  public struct Info: Encodable {
    public var bot: String
    public var url: String?
    public var job: Json.GitlabJob
    public var mr: UInt?
  }
}
public extension GitlabCi {
  static func getCurrentJob(
    verbose: Bool,
    env: [String: String]
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(apiV4.get(env: env))/job",
    headers: ["Authorization: Bearer \(jobToken.get(env: env))"]
  ))}
  func getJob(
    id: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/jobs/\(id)",
    headers: [botAuth.get()]
  ))}
  func getPipeline(
    pipeline: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/pipelines/\(pipeline)",
    headers: [botAuth.get()]
  ))}
  func getMrState(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(review)?include_rebase_in_progress=true",
    headers: [botAuth.get()]
  ))}
  func getMrAwarders(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(review)/award_emoji",
    headers: [botAuth.get()]
  ))}
  func postMrPipelines(
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(review)/pipelines",
    method: "POST",
    headers: [botAuth.get()]
  ))}
  func postMrAward(
    review: UInt,
    award: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(review)/award_emoji",
    method: "POST",
    form: ["name=\(award)"],
    headers: [botAuth.get()]
  ))}
  func putMrState(
    parameters: PutMrState,
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(review)",
    method: "PUT",
    data: parameters.curl.get(),
    headers: [botAuth.get(), Json.contentType]
  ))}
  func putMrMerge(
    parameters: PutMrMerge,
    review: UInt
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/merge_requests/\(review)/merge",
    method: "PUT",
    checkHttp: false,
    data: parameters.curl.get(),
    headers: [botAuth.get(), Json.contentType]
  ))}
  func postTriggerPipeline(
    ref: String,
    cfg: Configuration,
    variables: [String: String]
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/trigger/pipeline",
    method: "POST",
    form: [
      "token=\(jobToken)",
      "ref=\(ref)",
    ] + variables.compactMap { pair in pair.value
      .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
      .map { "variables[\(pair.key)]=\($0)" }
    }
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
  func getJobs(
    action: JobAction,
    pipeline: UInt,
    page: Int = 0
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/pipelines/\(pipeline)/jobs",
    form: [
      "include_retried=true",
      "page=\(page)",
      "per_page=\(100)",
    ] + action.scope.map { "scope[]=\($0)" },
    headers: [botAuth.get()]
  ))}
  func postJobsAction(
    job: UInt,
    action: JobAction
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/jobs/\(job)/\(action.rawValue)",
    method: "POST",
    headers: [botAuth.get()]
  ))}
  func postTags(
    name: String,
    ref: String,
    message: String
  ) -> Lossy<Execute> { .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/repository/tags",
    method: "POST",
    form: [
      "tag_name=\(name)",
      "ref=\(ref)",
      "message=\(message)",
    ],
    headers: [botAuth.get()]
  ))}
  func postBranches(
    name: String,
    ref: String
  ) -> Lossy<Execute> {
    guard let name = name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    else { return .error(MayDay("addingPercentEncoding failed")) }
    return .init(try .makeCurl(
    verbose: verbose,
    url: "\(url)/repository/branches",
    method: "POST",
    form: [
      "branch=\(name)",
      "ref=\(ref)",
    ],
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
