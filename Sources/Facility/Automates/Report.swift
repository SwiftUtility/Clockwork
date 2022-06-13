import Foundation
import Facility
public protocol Reportable: Encodable {
  var event: String { get }
}
public struct Report {
  public var event: String
  public var context: Encodable
  public init(_ reportable: Reportable) {
    self.event = reportable.event
    self.context = reportable
  }
  public struct Unexpected: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var error: String
  }
  public struct UnownedCode: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var files: [String]
  }
  public struct FileTabooIssues: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var issues: [FileTaboo.Issue]
  }
  public struct ReviewObsolete: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var obsoleteFiles: [String]?
    public var forbiddenCommits: [String]?
  }
  public struct ConflictMarkers: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var markers: [String]
  }
  public struct InvalidTitle: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var title: String
  }
  public struct ReviewBlocked: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var reasons: [Reason]
    public enum Reason: String, Encodable {
      case draft
      case workInProgress
      case blockingDiscussions
    }
  }
  public struct ReviewMergeConflicts: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewMerged: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewMergeError: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var error: String
  }
  public struct NewAwardApprovalGroup: Reportable {
    public let event: String
    public var env: [String: String]
    public var custom: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var group: AwardApproval.Group.Report
  }
  public struct NewAwardApprovals: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var groups: [AwardApproval.Group.Report]
  }
  public struct AwardApprovalHolders: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var holders: Set<String>
  }
  public struct ReleaseNotes: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var commits: [String]
  }
}
public extension Configuration {
  func reportUnexpected(
    error: Error
  ) -> Report { .init(Report.Unexpected(
    env: env,
    custom: controls.stencilCustom,
    error: "\(error)"
  ))}
  func reportUnownedCode(
    job: Json.GitlabJob,
    files: [String]
  ) -> Report { .init(Report.UnownedCode(
    env: env,
    custom: controls.stencilCustom,
    user: job.user.username,
    files: files
  ))}
  func reportFileTabooIssues(
    job: Json.GitlabJob,
    issues: [FileTaboo.Issue]
  ) -> Report { .init(Report.FileTabooIssues(
    env: env,
    custom: controls.stencilCustom,
    user: job.user.username,
    issues: issues
  ))}
  func reportReviewObsolete(
    job: Json.GitlabJob,
    obsoleteFiles: [String],
    forbiddenCommits: [String]
  ) -> Report { .init(Report.ReviewObsolete(
    env: env,
    custom: controls.stencilCustom,
    user: job.user.username,
    obsoleteFiles: obsoleteFiles.isEmpty.else(obsoleteFiles),
    forbiddenCommits: forbiddenCommits.isEmpty.else(forbiddenCommits)
  ))}
  func reportConflictMarkers(
    job: Json.GitlabJob,
    markers: [String]
  ) -> Report { .init(Report.ConflictMarkers(
    env: env,
    custom: controls.stencilCustom,
    user: job.user.username,
    markers: markers
  ))}
  func reportInvalidTitle(
    job: Json.GitlabJob,
    title: String
  ) -> Report { .init(Report.InvalidTitle(
    env: env,
    custom: controls.stencilCustom,
    user: job.user.username,
    title: title
  ))}
  func reportReviewBlocked(
    review: Json.GitlabReviewState,
    users: [String],
    reasons: [Report.ReviewBlocked.Reason]
  ) -> Report { .init(Report.ReviewBlocked(
    env: env,
    custom: controls.stencilCustom,
    review: review,
    users: .init(users)
      .union([review.author.username]),
    reasons: reasons
  ))}
  func reportReviewMergeConflicts(
    review: Json.GitlabReviewState,
    users: [String]
  ) -> Report { .init(Report.ReviewMergeConflicts(
    env: env,
    custom: controls.stencilCustom,
    review: review,
    users: .init(users)
      .union([review.author.username])
  ))}
  func reportReviewMerged(
    review: Json.GitlabReviewState,
    users: [String]
  ) -> Report { .init(Report.ReviewMerged(
    env: env,
    custom: controls.stencilCustom,
    review: review,
    users: .init(users)
      .union([review.author.username])
  ))}
  func reportReviewMergeError(
    review: Json.GitlabReviewState,
    users: [String],
    error: String
  ) -> Report { .init(Report.ReviewMergeError(
    env: env,
    custom: controls.stencilCustom,
    review: review,
    users: .init(users)
      .union([review.author.username]),
    error: error
  ))}
  func reportNewAwardApprovalGroup(
    review: Json.GitlabReviewState,
    users: Set<String>,
    group: AwardApproval.Group.Report
  ) -> Report { .init(Report.NewAwardApprovalGroup(
    event: "\(Report.NewAwardApprovalGroup.self)\(group.name)",
    env: env,
    custom: controls.stencilCustom,
    review: review,
    users: users,
    group: group
  ))}
  func reportNewAwardApprovals(
    review: Json.GitlabReviewState,
    users: Set<String>,
    groups: [AwardApproval.Group.Report]
  ) -> Report { .init(Report.NewAwardApprovals(
    env: env,
    custom: controls.stencilCustom,
    review: review,
    users: users,
    groups: groups
  ))}
  func reportAwardApprovalHolders(
    review: Json.GitlabReviewState,
    users: Set<String>,
    holders: Set<String>
  ) -> Report { .init(Report.AwardApprovalHolders(
    env: env,
    custom: controls.stencilCustom,
    review: review,
    users: users,
    holders: holders
  ))}
  func reportReleaseNotes(
    job: Json.GitlabJob,
    commits: [String]
  ) -> Report { .init(Report.ReleaseNotes(
    env: env,
    custom: controls.stencilCustom,
    user: job.user.username,
    commits: commits
  ))}
}
//
//public enum Report {
//  case unepected(Unepected)
//  case fileRulesIssues(FileRulesIssues)
//  case approvalGroup(ApprovalGroup)
//  case approvalGroups(ApprovalGroups)
//  case approvalHolders(ApprovalHolders)
//  case releaseNotes(ReleaseNotes)
//
//
//  case validationIssues([String])
//  case review(Json.GitlabReviewState, Review)
//  case replicationConflicts(Configuration.Merge.Context)
//  public var name: String {
//    switch self {
//    case .unepected: return "Unepected"
//    case .fileRulesIssues: return "FileRulesIssues"
//    case .approvalGroup(let approvalGroup): return "ApprovalBy\(approvalGroup.group.name)"
//    case .approvalGroups: return "ApprovalGroups"
//    case .approvalHolders: return "ApprovalHolders"
//    case .releaseNotes: return "ReleaseNotes"
//
//
//
//    case .validationIssues: return "ValidationIssues"
//    case .review(_, let review):
//      switch review {
//      case .mergeError: return "ReviewMergeError"
//      case .mergeConflicts: return "ReviewConflicts"
//      case .issues: return "ReviewIssues"
//      case .invalidTitle: return "ReviewInvalidTitle"
//      case .accepted: return "ReviewAccepted"
//      }
//    case .replicationConflicts: return "ReplicationConflicts"
//    }
//  }
//  public func makeContext(cfg: Configuration) -> Encodable {
//    switch self {
//    case .unepected(let context): return context
//    case .fileRulesIssues(let context): return context
//    case .approvalGroup(let context): return context
//    case .approvalGroups(let context): return context
//    case .approvalHolders(let context): return context
//    case .releaseNotes(let context): return context
//
//
//
//    case .validationIssues(let issues): return Context(issues: issues).add(cfg: cfg)
//    case .review(let state, let review):
//      switch review {
//      case .mergeError(let error): return Context(error: error, review: .init(state: state)).add(cfg: cfg)
//      case .mergeConflicts: return Context(review: .init(state: state)).add(cfg: cfg)
//      case .issues(let issues): return Context(issues: issues, review: .init(state: state)).add(cfg: cfg)
//      case .invalidTitle: return Context(review: .init(state: state)).add(cfg: cfg)
//      case .accepted: return Context(review: .init(state: state)).add(cfg: cfg)
//      }
//    case .replicationConflicts(let context): return context
//    }
//  }
//  public struct Unepected: Codable {
//    public var env: [String: String]
//    public var custom: AnyCodable?
//    public var user: String?
//    public var error: String
//  }
//  public struct FileRulesIssues: Codable {
//    public var env: [String: String]
//    public var custom: AnyCodable?
//    public var user: String?
//    public var issues: [FileRule.Issue]
//  }
//  public struct ApprovalGroup: Codable {
//    public var env: [String: String]
//    public var custom: AnyCodable?
//    public var review: Json.GitlabReviewState
//    public var user: String?
//    public var group: AwardApproval.Context
//  }
//  public struct ApprovalGroups: Codable {
//    public var env: [String: String]
//    public var custom: AnyCodable?
//    public var review: Json.GitlabReviewState
//    public var user: String?
//    public var groups: [AwardApproval.Context]
//  }
//  public struct ApprovalHolders: Codable {
//    public var env: [String: String]
//    public var custom: AnyCodable?
//    public var review: Json.GitlabReviewState
//    public var user: String?
//    public var holders: Set<String>
//  }
//  public struct ReleaseNotes: Codable {
//    public var custom: AnyCodable?
//    public var commits: [String]
//  }
//  public enum Review {
//    case mergeError(String)
//    case mergeConflicts
//    case issues([String])
//    case invalidTitle
//    case accepted
//  }
//  public struct Context: Encodable {
//    public var env: [String: String]?
//    public var custom: AnyCodable?
//    public var issues: [String]?
//    public var error: String?
//    public var review: Review?
//    public func add(cfg: Configuration) -> Self {
//      var this = self
//      this.env = cfg.env
//      this.custom = cfg.custom
//      return this
//    }
//    public static func make(review state: Json.GitlabReviewState) -> Self {
//      .init(review: .init(state: state))
//    }
//    public struct Git: Encodable {
//      public var author: String?
//      public var head: String?
//    }
//    public struct Review: Encodable {
//      public var state: Json.GitlabReviewState?
//      public var holders: Set<String>?
//      public var approval: AwardApproval.Context?
//      public var approvals: [AwardApproval.Context]?
//    }
//  }
//}
