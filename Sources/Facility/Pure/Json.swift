import Foundation
import Facility
public enum Json {
  public static var contentType: String { "Content-Type: application/json" }
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
    public func makeBranchBuild(build: String) throws -> Production.Build {
      guard !tag else { throw Thrown("Tag builds not supported") }
      return .branch(.init(build: build, sha: pipeline.sha, branch: pipeline.ref))
    }
    public struct Pipeline: Codable {
      public var id: UInt
      public var ref: String
      public var sha: String
    }
  }
  public struct GitlabCommitMergeRequest: Codable {
    public var squashCommitSha: String?
    public var author: GitlabUser
  }
  public struct GitlabReviewState: Codable {
    public var title: String
    public var state: String
    public var targetBranch: String
    public var sourceBranch: String
    public var author: GitlabUser
    public var draft: Bool
    public var workInProgress: Bool
    public var mergeStatus: String
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
}
