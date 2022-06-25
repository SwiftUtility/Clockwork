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
  public var review: UInt?
  public var botAuth: Lossy<String>
  public var pushUrl: Lossy<String>
  public var parent: Parent
  public var url: String { "\(api)/projects/\(project)" }
  public var info: Info { .init(
    job: job,
    bot: botLogin,
    url: job.webUrl
      .components(separatedBy: "/-/")
      .first,
    mr: review,
    parentMr: try? parent.review.get(),
    parentPipe: try? parent.pipeline.get()
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
    let trigger = Trigger(
      name: yaml.trigger.name,
      review: yaml.trigger.review,
      profile: yaml.trigger.profile,
      pipeline: yaml.trigger.pipeline
    )
    return .init(try .init(
      verbose: verbose,
      botLogin: yaml.bot.login,
      trigger: trigger,
      api: apiV4.get(env: env),
      project: projectId.get(env: env),
      config: config.get(env: env),
      job: job.get(),
      jobToken: jobToken.get(env: env),
      review: try? job
        .map(\.pipeline.ref)
        .reduce(curry: "refs/merge-requests/", String.dropPrefix(_:))
        .reduce(curry: "/head", String.dropSuffix(_:))
        .map(UInt.init(_:))
        .get(),
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
      parent: .init(
        name: Lossy(try trigger.name.get(env: env)),
        review: Lossy(env[trigger.review])
          .reduce(Thrown("Triggered not from review"), Optional.get(or:value:))
          .map(UInt.init(_:))
          .reduce(Thrown("Malformed \(trigger.review)"), Optional.get(or:value:)),
        profile: Lossy(try .init(value: trigger.profile.get(env: env))),
        pipeline: Lossy(try trigger.pipeline.get(env: env))
          .map(UInt.init(_:))
          .reduce(Thrown("Malformed \(trigger.pipeline)"), Optional.get(or:value:))
      )
    ))
  }
  public static func makeApiToken(
    env: [String: String],
    yaml: Yaml.Controls.GitlabCi
  ) -> Lossy<Secret> {
    guard case "true" = env[Self.protected]
    else { return .error(Thrown("Not in protected pipeline")) }
    return Lossy.value(yaml.bot.apiToken)
      .reduce(Thrown("apiToken not configured"), Optional.get(or:value:))
      .map(Secret.init(yaml:))
  }
  public static func makePushToken(
    env: [String: String],
    yaml: Yaml.Controls.GitlabCi
  ) -> Lossy<Secret> {
    guard case "true" = env[Self.protected]
    else { return .error(Thrown("Not in protected pipeline")) }
    return Lossy.value(yaml.bot.pushToken)
      .reduce(Thrown("pushToken not configured"), Optional.get(or:value:))
      .map(Secret.init(yaml:))
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
    public var name: String
    public var review: String
    public var profile: String
    public var pipeline: String
  }
  public struct Parent {
    public var name: Lossy<String>
    public var review: Lossy<UInt>
    public var profile: Lossy<Files.Relative>
    public var pipeline: Lossy<UInt>
  }
  public struct Info: Encodable {
    public var job: Json.GitlabJob
    public var bot: String
    public var url: String?
    public var mr: UInt?
    public var parentMr: UInt?
    public var parentPipe: UInt?
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
    cfg: Configuration,
    variables: [String: String]
  ) -> Lossy<Execute> { .init(.makeCurl(
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
    url: "\(url)/pipelines/\(pipeline)/jobs?\(action.jobsQuery(page: page))",
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
        .get { throw Thrown("Invalid tag annotation message") }
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
