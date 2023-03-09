import Foundation
import Facility
public enum Json {
  public static var contentType: String { "Content-Type: application/json" }
  public static var utf8: String { "Content-Type: application/json; charset=utf-8" }
  public struct GitlabPipeline: Codable {
    public var id: UInt
    public var status: String
    public var ref: String
    public var sha: String
    public var tag: Bool
    public var user: GitlabUser
  }
  public struct GitlabDiscussion: Codable {
    public var id: String
    public var individualNote: Bool
    public var notes: [GitlabNote]
  }
  public struct GitlabNote: Codable {
    public var id: UInt
    public var author: GitlabUser
    public var resolved: Bool?
    public var resolvable: Bool
  }
  public struct GitlabJob: Codable {
    public var id: UInt
    public var name: String
    public var user: GitlabUser
    public var pipeline: Pipeline
    public var tag: Bool
    public var webUrl: String
    public var review: Lossy<UInt> {
      .init(try pipeline.ref.dropPrefix("refs/merge-requests/").dropSuffix("/head").getUInt())
    }
    public func getLogin(approvers: [String: Gitlab.Storage.User]) throws -> String {
      let login = user.username
      guard let approver = approvers[login] else { throw Thrown("Unknown user: \(login)") }
      guard approver.active else { throw Thrown("Inactive approver: \(login)") }
      return login
    }
    public struct Pipeline: Codable {
      public var id: UInt
      public var ref: String
      public var sha: String
      public var projectId: UInt
    }
  }
  public struct GitlabTag: Codable {
    public var protected: Bool
  }
  public struct GitlabCommitMergeRequest: Codable {
    public var squashCommitSha: String?
    public var iid: UInt
    public var projectId: UInt
    public var author: GitlabUser
  }
  public struct GitlabMerge: Codable {
    public var title: String
    public var state: String
    public var targetBranch: String
    public var sourceBranch: String
    public var author: GitlabUser
    public var closedBy: GitlabUser?
    public var draft: Bool
    public var workInProgress: Bool
    public var mergeStatus: String
    public var squash: Bool
    public var mergeError: String?
    public var pipeline: Pipeline?
    public var headPipeline: Pipeline?
    public var lastPipeline: Pipeline { headPipeline.get(pipeline!) }
    public var rebaseInProgress: Bool?
    public var hasConflicts: Bool
    public var blockingDiscussionsResolved: Bool
    public var labels: [String]
    public var iid: UInt
    public var webUrl: String
    public var isClosed: Bool { state == "closed" }
    public var isMerged: Bool { state == "merged" }
    public struct Pipeline: Codable {
      public var id: UInt
      public var sha: String
      public var status: String
      public var isFailed: Bool { status == "failed" }
    }
  }
  public struct GitlabAward: Codable {
    public var id: Int
    public var name: String
    public var user: GitlabUser
  }
  public struct GitlabUser: Codable {
    public var id: Int
    public var name: String
    public var username: String
  }
  public struct GitlabBranch: Codable {
    public var name: String
    public var protected: Bool
    public var `default`: Bool
  }
  public struct GitlabProject: Codable {
    public var defaultBranch: String
    public var sshUrlToRepo: String // git@example.com:diaspora/diaspora-project-site.git
    public var httpUrlToRepo: String // http://example.com/diaspora/diaspora-project-site.git
    public var webUrl: String // http://example.com/diaspora/diaspora-project-site
  }
  public struct SlackMessage: Codable {
    public var channel: String
    public var ts: String
  }
  public struct RocketReply: Codable {
    public var message: Message
    public struct Message: Codable {
      public var id: String
      public var rid: String
      public enum CodingKeys: String, CodingKey {
        case id = "_id"
        case rid = "rid"
      }
    }
  }
  public struct FileTaboo: Codable {
    public var rule: String
    public var file: String
    public var line: Int?
    public var logMessage: LogMessage {
      .init(message: "\(file):\(line.map { "\($0):" }.get("")) \(rule)")
    }
    public static func make(
      rule: String,
      file: String,
      line: Int? = nil
    ) -> Self { .init(
      rule: rule,
      file: file,
      line: line
    )}
  }
  public struct ExpiringRequisite: Encodable {
    public var file: String
    public var branch: String
    public var name: String
    public var days: String?
    public var logMessage: String {
      let expire = days.map({ "expires in \($0) days" }).get("expired")
      return "\(branch):\(file): \(name) \(expire)"
    }
    public static func make(
      file: String,
      branch: String,
      name: String,
      days: TimeInterval
    ) -> Self { .init(
      file: file,
      branch: branch,
      name: name,
      days: (days > 0).then("\(Int(days))")
    )}
  }
  public struct FusionTargets: Encodable {
    public var fork: String
    public var source: String
    public var integrate: [String]
    public var duplicate: [String]?
    public var propogate: [String]?
    public static func make(
      fork: Ctx.Git.Sha,
      source: Ctx.Git.Branch,
      integrate: [Ctx.Git.Branch],
      duplicate: Bool,
      propogate: [Ctx.Git.Branch]
    ) -> Self { .init(
      fork: fork.value,
      source: source.name,
      integrate: integrate.map(\.name),
      duplicate: duplicate.then(integrate.map(\.name)),
      propogate: propogate.isEmpty.not.then(propogate.map(\.name))
    )}
  }
}
