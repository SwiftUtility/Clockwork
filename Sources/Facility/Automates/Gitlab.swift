import Foundation
import Facility
public struct Gitlab {
  public var api: String
  public var project: String
  public var jobToken: String
  public var scheme: String
  public var host: String
  public var port: String
  public var path: String
  public var botLogin: String
  public var parentPipeline: String
  public var parentReview: String
  public var parentProfile: String
  public var sanityFiles: [String]
  public var triggererPipeline: UInt?
  public var triggererReview: UInt?
  public var triggererProfile: Path.Relative?
  public var botToken: String?
  public init(env: [String: String], yaml: Yaml.Gitlab) throws {
    self.api = try env["CI_API_V4_URL"].or { throw Thrown("No env CI_API_V4_URL") }
    self.project = try env["CI_PROJECT_ID"].or { throw Thrown("No env CI_PROJECT_ID") }
    self.scheme = try env["CI_SERVER_PROTOCOL"].or { throw Thrown("No env CI_SERVER_PROTOCOL") }
    self.host = try env["CI_SERVER_HOST"].or { throw Thrown("No env CI_SERVER_HOST") }
    self.port = try env["CI_SERVER_PORT"].or { throw Thrown("No env CI_SERVER_PORT") }
    self.path = try env["CI_PROJECT_PATH"].or { throw Thrown("No env CI_PROJECT_PATH") }
    self.jobToken = try env["CI_JOB_TOKEN"].or { throw Thrown("No env CI_JOB_TOKEN") }
    self.sanityFiles = try env["CI_CONFIG_PATH"]
      .makeArray()
      .mapEmpty { throw Thrown("No env CI_CONFIG_PATH") }
    self.botLogin = yaml.botLogin
    self.parentPipeline = yaml.parentPipeline
    self.parentReview = yaml.parentReview
    self.parentProfile = yaml.parentProfile
    if case "true" = env["CI_PIPELINE_TRIGGERED"] {
      if let triggererPipeline = env[yaml.parentPipeline] {
        self.triggererPipeline = try .init(triggererPipeline)
          .or { throw Thrown("parentPipeline wrong format") }
      }
      if let triggererReview = env[yaml.parentReview] {
        self.triggererReview = try .init(triggererReview)
          .or { throw Thrown("parentReview wrong format") }
      }
      if let triggererProfile = env[yaml.parentProfile] {
        self.triggererProfile = try .init(path: triggererProfile)
      }
    }
  }
  public func makeTriggererVariables(cfg: Configuration) throws -> [String: String] {
    var result = try [
      parentPipeline: cfg.get(env: "CI_PIPELINE_ID"),
      parentProfile: cfg.profile.profile.path.path,
    ]
    result[parentReview] = cfg.env["CI_MERGE_REQUEST_IID"]
    return result
  }
  public func makeBotToken() throws -> String {
    try botToken.or { throw Thrown("botToken not available") }
  }
  public func makePushUrl() throws -> String {
    try "\(scheme)://\(botLogin):\(makeBotToken())@\(host):\(port)/\(path)"
  }
  public static func makeUser(env: [String: String]) -> String? { env["GITLAB_USER_LOGIN"] }
  public func makeBotToken(env: [String: String], yaml: Yaml.Gitlab) throws -> Configuration.Token? {
    guard case "true" = env["CI_COMMIT_REF_PROTECTED"] else { return nil }
    return try .init(yaml: yaml.botToken)
  }
  public static var json: String { "Content-Type: application/json" }
}
