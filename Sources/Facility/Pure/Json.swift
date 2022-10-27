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
    public func matches(build: Production.Build) -> Bool {
      guard !tag else { return false }
      if let review = try? review.get() {
        guard case .review(let value) = build else { return false }
        return value.sha == pipeline.sha && value.review == review
      } else {
        guard case .branch(let value) = build else { return false }
        return value.sha == pipeline.sha && value.branch == pipeline.ref
      }
    }
    public func makeBuild(build: String) -> Production.Build {
      if tag {
        return .tag(.make(build: build.alphaNumeric, sha: pipeline.sha, tag: pipeline.ref))
      } else {
        return .branch(.make(build: build.alphaNumeric, sha: pipeline.sha, branch: pipeline.ref))
      }
    }
    public func getLogin(approvers: [String: Fusion.Approval.Approver]) throws -> String {
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
  public struct GitlabCommitMergeRequest: Codable {
    public var squashCommitSha: String?
    public var iid: UInt
    public var projectId: UInt
    public var author: GitlabUser
  }
  public struct GitlabReviewState: Codable {
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
    public func matches(build: Production.Build) -> Bool {
      guard case .review(let value) = build else { return false }
      return value.sha == lastPipeline.sha && value.review == iid
    }
    public func makeBuild(build: String) -> Production.Build { .review(.make(
      build: .make(build),
      sha: lastPipeline.sha,
      review: iid,
      target: targetBranch
    ))}
    public struct Pipeline: Codable {
      public var id: UInt
      public var sha: String
      public var status: String
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
    public var httpUrlToRepo: String // http://example.com/diaspora/diaspora-project-site.git
    public var webUrl: String // http://example.com/diaspora/diaspora-project-site
  }
  public struct SlackMessage: Codable {
    public var channel: String
    public var ts: String
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
}
