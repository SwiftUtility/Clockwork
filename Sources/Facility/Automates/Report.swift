import Foundation
import Facility
public enum Report {
  case unepected(Unepected)
  case fileRulesIssues(FileRulesIssues)
  case approvalGroup(ApprovalGroup)
  case approvalGroups(ApprovalGroups)
  case approvalHolders(ApprovalHolders)



  case validationIssues([String])
  case review(Json.GitlabReviewState, Review)
  case replicationConflicts(Configuration.Merge.Context)
  public var name: String {
    switch self {
    case .unepected: return "Unepected"
    case .fileRulesIssues: return "FileRulesIssues"
    case .approvalGroup(let approvalGroup): return "ApprovalBy\(approvalGroup.group.name)"
    case .approvalGroups: return "ApprovalGroups"
    case .approvalHolders: return "ApprovalHolders"



    case .validationIssues: return "ValidationIssues"
    case .review(_, let review):
      switch review {
      case .mergeError: return "ReviewMergeError"
      case .mergeConflicts: return "ReviewConflicts"
      case .issues: return "ReviewIssues"
      case .invalidTitle: return "ReviewInvalidTitle"
      case .accepted: return "ReviewAccepted"
      }
    case .replicationConflicts: return "ReplicationConflicts"
    }
  }
  public func makeContext(cfg: Configuration) -> Encodable {
    switch self {
    case .unepected(let context): return context
    case .fileRulesIssues(let context): return context
    case .approvalGroup(let context): return context
    case .approvalGroups(let context): return context
    case .approvalHolders(let context): return context



    case .validationIssues(let issues): return Context(issues: issues).add(cfg: cfg)
    case .review(let state, let review):
      switch review {
      case .mergeError(let error): return Context(error: error, review: .init(state: state)).add(cfg: cfg)
      case .mergeConflicts: return Context(review: .init(state: state)).add(cfg: cfg)
      case .issues(let issues): return Context(issues: issues, review: .init(state: state)).add(cfg: cfg)
      case .invalidTitle: return Context(review: .init(state: state)).add(cfg: cfg)
      case .accepted: return Context(review: .init(state: state)).add(cfg: cfg)
      }
    case .replicationConflicts(let context): return context
    }
  }
  public struct Unepected: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String?
    public var error: String
  }
  public struct FileRulesIssues: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String?
    public var issues: [FileRule.Issue]
  }
  public struct ApprovalGroup: Codable {
    public var env: [String: String]
    public var review: Json.GitlabReviewState
    public var custom: AnyCodable?
    public var user: String?
    public var group: AwardApproval.Context
  }
  public struct ApprovalGroups: Codable {
    public var env: [String: String]
    public var review: Json.GitlabReviewState
    public var custom: AnyCodable?
    public var user: String?
    public var groups: [AwardApproval.Context]
  }
  public struct ApprovalHolders: Codable {
    public var env: [String: String]
    public var review: Json.GitlabReviewState
    public var custom: AnyCodable?
    public var user: String?
    public var holders: Set<String>
  }
  public enum Review {
    case mergeError(String)
    case mergeConflicts
    case issues([String])
    case invalidTitle
    case accepted
  }
  public struct Context: Encodable {
    public var env: [String: String]?
    public var custom: AnyCodable?
    public var issues: [String]?
    public var error: String?
    public var review: Review?
    public func add(cfg: Configuration) -> Self {
      var this = self
      this.env = cfg.env
      this.custom = cfg.stencil.custom
      return this
    }
    public static func make(review state: Json.GitlabReviewState) -> Self {
      .init(review: .init(state: state))
    }
    public struct Git: Encodable {
      public var author: String?
      public var head: String?
    }
    public struct Review: Encodable {
      public var state: Json.GitlabReviewState?
      public var holders: Set<String>?
      public var approval: AwardApproval.Context?
      public var approvals: [AwardApproval.Context]?
    }
  }
}
public extension Configuration {
  func makeReport(error: Error) -> Report { .unepected(.init(
    env: env,
    custom: stencil.custom,
    user: Gitlab.makeUser(env: env),
    error: "\(error)"
  ))}
  var fileRulesIssues: Report.FileRulesIssues { .init(
    env: env,
    custom: stencil.custom,
    user: Gitlab.makeUser(env: env),
    issues: []
  )}
}
