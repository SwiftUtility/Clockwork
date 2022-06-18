import Foundation
import Facility
public protocol Reportable: Encodable {
  var event: String { get }
}
public struct Report: Query {
  public var cfg: Configuration
  public var reportable: Reportable
  public typealias Reply = Void
  public struct Unexpected: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var error: String
  }
  public struct UnownedCode: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var user: String
    public var files: [String]
  }
  public struct FileTabooIssues: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var user: String
    public var issues: [FileTaboo.Issue]
  }
  public struct ReviewObsolete: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var user: String
    public var obsoleteFiles: [String]?
    public var forbiddenCommits: [String]?
  }
  public struct ConflictMarkers: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var user: String
    public var markers: [String]
  }
  public struct InvalidTitle: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var user: String
    public var title: String
  }
  public struct ReviewBlocked: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
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
    public var ctx: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewMerged: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewMergeError: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var error: String
  }
  public struct NewAwardApprovalGroup: Reportable {
    public let event: String
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var group: AwardApproval.Group.New
  }
  public struct NewAwardApprovals: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var groups: [AwardApproval.Group.New]
  }
  public struct AwardApprovalHolders: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var holders: Set<String>
  }
  public struct ReleaseNotes: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var user: String
    public var commits: [String]
  }
  public struct ExpiringRequisites: Reportable {
    public let event: String = "\(Self.self)"
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var items: [Item]
    public struct Item: Encodable {
      public var file: String
      public var name: String
      public var days: String
      public init(file: String, name: String, days: String) {
        self.file = file
        self.name = name
        self.days = days
      }
    }
  }
}
public extension Configuration {
  func reportUnexpected(
    error: Error
  ) -> Report { .init(cfg: self, reportable: Report.Unexpected(
    env: env,
    ctx: controls.context,
    error: "\(error)"
  ))}
  func reportUnownedCode(
    job: Json.GitlabJob,
    files: [String]
  ) -> Report { .init(cfg: self, reportable: Report.UnownedCode(
    env: env,
    ctx: controls.context,
    user: job.user.username,
    files: files
  ))}
  func reportFileTabooIssues(
    job: Json.GitlabJob,
    issues: [FileTaboo.Issue]
  ) -> Report { .init(cfg: self, reportable: Report.FileTabooIssues(
    env: env,
    ctx: controls.context,
    user: job.user.username,
    issues: issues
  ))}
  func reportReviewObsolete(
    job: Json.GitlabJob,
    obsoleteFiles: [String],
    forbiddenCommits: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ReviewObsolete(
    env: env,
    ctx: controls.context,
    user: job.user.username,
    obsoleteFiles: obsoleteFiles.isEmpty.else(obsoleteFiles),
    forbiddenCommits: forbiddenCommits.isEmpty.else(forbiddenCommits)
  ))}
  func reportConflictMarkers(
    job: Json.GitlabJob,
    markers: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ConflictMarkers(
    env: env,
    ctx: controls.context,
    user: job.user.username,
    markers: markers
  ))}
  func reportInvalidTitle(
    job: Json.GitlabJob,
    title: String
  ) -> Report { .init(cfg: self, reportable: Report.InvalidTitle(
    env: env,
    ctx: controls.context,
    user: job.user.username,
    title: title
  ))}
  func reportReviewBlocked(
    review: Json.GitlabReviewState,
    users: [String],
    reasons: [Report.ReviewBlocked.Reason]
  ) -> Report { .init(cfg: self, reportable: Report.ReviewBlocked(
    env: env,
    ctx: controls.context,
    review: review,
    users: .init(users)
      .union([review.author.username]),
    reasons: reasons
  ))}
  func reportReviewMergeConflicts(
    review: Json.GitlabReviewState,
    users: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ReviewMergeConflicts(
    env: env,
    ctx: controls.context,
    review: review,
    users: .init(users)
      .union([review.author.username])
  ))}
  func reportReviewMerged(
    review: Json.GitlabReviewState,
    users: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ReviewMerged(
    env: env,
    ctx: controls.context,
    review: review,
    users: .init(users)
      .union([review.author.username])
  ))}
  func reportReviewMergeError(
    review: Json.GitlabReviewState,
    users: [String],
    error: String
  ) -> Report { .init(cfg: self, reportable: Report.ReviewMergeError(
    env: env,
    ctx: controls.context,
    review: review,
    users: .init(users)
      .union([review.author.username]),
    error: error
  ))}
  func reportNewAwardApprovalGroup(
    review: Json.GitlabReviewState,
    users: Set<String>,
    group: AwardApproval.Group.New
  ) -> Report { .init(cfg: self, reportable: Report.NewAwardApprovalGroup(
    event: "\(Report.NewAwardApprovalGroup.self)\(group.name)",
    env: env,
    ctx: controls.context,
    review: review,
    users: users,
    group: group
  ))}
  func reportNewAwardApprovals(
    review: Json.GitlabReviewState,
    users: Set<String>,
    groups: [AwardApproval.Group.New]
  ) -> Report { .init(cfg: self, reportable: Report.NewAwardApprovals(
    env: env,
    ctx: controls.context,
    review: review,
    users: users,
    groups: groups
  ))}
  func reportAwardApprovalHolders(
    review: Json.GitlabReviewState,
    users: Set<String>,
    holders: Set<String>
  ) -> Report { .init(cfg: self, reportable: Report.AwardApprovalHolders(
    env: env,
    ctx: controls.context,
    review: review,
    users: users,
    holders: holders
  ))}
  func reportReleaseNotes(
    job: Json.GitlabJob,
    commits: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ReleaseNotes(
    env: env,
    ctx: controls.context,
    user: job.user.username,
    commits: commits
  ))}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) -> Report { .init(cfg: self, reportable: Report.ExpiringRequisites(
    env: env,
    ctx: controls.context,
    items: items
  ))}
}
extension Configuration.Controls {
  public func generateReport(
    template: String,
    reportable: Reportable
  ) -> Generate { .init(
    template: template,
    templates: templates,
    context: reportable
  )}
}
