import Foundation
import Facility
public enum Json {
  public struct GitlabRebase: Codable {
    public var rebaseInProgress: Bool
  }
  public struct GitlabPipeline: Codable {
    public var id: UInt
    public var status: String
    public var ref: String
    public var sha: String
    public var user: GitlabUser
  }
  public struct GitlabCommitMergeRequest: Codable {
    public var squashCommitSha: String
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
    public var pipeline: Pipeline
    public var rebaseInProgress: Bool?
    public var hasConflicts: Bool
    public var blockingDiscussionsResolved: Bool
    public var labels: [String]
    public struct Pipeline: Codable {
      public var id: UInt
      public var sha: String
    }
  }
  public struct GitlabAward: Codable {
    public var id: Int
    public var name: String
    public var user: GitlabUser
  }
  public struct GitlabUser: Codable {
    public var username: String
  }
}
