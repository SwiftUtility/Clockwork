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
