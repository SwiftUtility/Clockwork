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
  public var botToken: Configuration.Token?
  public var token: String?
  public var user: String
  public init(cfg: Configuration) throws {
    let yaml = try cfg.gitlab.or { throw Thrown("gitlab not configured") }
    self.api = try cfg.get(env: "CI_API_V4_URL")
    self.project = try cfg.get(env: "CI_PROJECT_ID")
    self.scheme = try cfg.get(env: "CI_SERVER_PROTOCOL")
    self.host = try cfg.get(env: "CI_SERVER_HOST")
    self.port = try cfg.get(env: "CI_SERVER_PORT")
    self.path = try cfg.get(env: "CI_PROJECT_PATH")
    self.jobToken = try cfg.get(env: "CI_JOB_TOKEN")
    self.user = try cfg.get(env: "GITLAB_USER_LOGIN")
    self.sanityFiles = try [cfg.get(env: Self.configPath)]
    self.botLogin = yaml.botLogin
    self.parentPipeline = yaml.parentPipeline
    self.parentReview = yaml.parentReview
    self.parentProfile = yaml.parentProfile
    if case "true" = cfg.env["CI_PIPELINE_TRIGGERED"] {
      if let triggererPipeline = cfg.env[yaml.parentPipeline] {
        self.triggererPipeline = try .init(triggererPipeline)
          .or { throw Thrown("parentPipeline wrong format") }
      }
      if let triggererReview = cfg.env[yaml.parentReview] {
        self.triggererReview = try .init(triggererReview)
          .or { throw Thrown("parentReview wrong format") }
      }
      if let triggererProfile = cfg.env[yaml.parentProfile] {
        self.triggererProfile = try .init(path: triggererProfile)
      }
    }
    if case "true" = cfg.env["CI_COMMIT_REF_PROTECTED"] {
      self.botToken = try .init(yaml: yaml.botToken)
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
    try token.or { throw Thrown("botToken not available") }
  }
  public func makePushUrl() throws -> String {
    try "\(scheme)://\(botLogin):\(makeBotToken())@\(host):\(port)/\(path)"
  }
  public static func makeUser(env: [String: String]) -> String? { env["GITLAB_USER_LOGIN"] }
  public static var json: String { "Content-Type: application/json" }
  public static var commitBranch: String { "CI_COMMIT_BRANCH" }
  public static var configPath: String { "CI_CONFIG_PATH" }
  public static var userLogin: String { "GITLAB_USER_LOGIN" }
  public enum JobAction: String {
    case play = "play"
    case cancel = "cancel"
    case retry = "retry"
    public var scope: String {
      switch self {
      case .play: return "scope=manual"
      case .cancel: return "scope[]=pending&scope[]=running&scope[]=created"
      case .retry: return "scope[]=failed&scope[]=canceled"
      }
    }
  }
}
