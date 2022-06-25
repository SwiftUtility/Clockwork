import Foundation
import Facility
public protocol Reportable: Encodable {
  var event: String { get }
}
public extension Reportable {
  static var event: String { "\(Self.self)" }
}
public struct Report: Query {
  public var cfg: Configuration
  public var reportable: Reportable
  public typealias Reply = Void
  public struct Custom: Reportable {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var stdin: [String]
  }
  public struct Unexpected: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var error: String
  }
  public struct UnownedCode: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var files: [String]
  }
  public struct FileTabooIssues: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var issues: [FileTaboo.Issue]
  }
  public struct ReviewObsolete: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var files: [String]?
  }
  public struct ForbiddenCommits: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var commits: [String]?
  }
  public struct ConflictMarkers: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var markers: [String]
  }
  public struct InvalidTitle: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewBlocked: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
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
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewMerged: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewMergeError: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var error: String
  }
  public struct EmergencyAwardApproval: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var cheaters: Set<String>
  }
  public struct DoneAwardApproval: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct NewAwardApproval: Reportable {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var group: AwardApproval.Group.Report
  }
  public struct WaitAwardApproval: Reportable {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var group: AwardApproval.Group.Report
  }
  public struct NewAwardApprovals: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var groups: [AwardApproval.Group.Report]
  }
  public struct WaitAwardApprovals: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var groups: [AwardApproval.Group.Report]
  }
  public struct AwardApprovalHolders: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var holders: Set<String>
  }
  public struct ReleaseNotes: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var commits: [String]
  }
  public struct ExpiringRequisites: Reportable {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
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
  func reportCustom(
    event: String,
    stdin: [String]
  ) -> Report { .init(cfg: self, reportable: Report.Custom(
    event: "\(Report.Custom.event)/\(event)",
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    stdin: stdin
  ))}
  func reportUnexpected(
    error: Error
  ) -> Report { .init(cfg: self, reportable: Report.Unexpected(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    error: "\(error)"
  ))}
  func reportUnownedCode(
    files: [String]
  ) -> Report { .init(cfg: self, reportable: Report.UnownedCode(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    files: files
  ))}
  func reportFileTabooIssues(
    issues: [FileTaboo.Issue]
  ) -> Report { .init(cfg: self, reportable: Report.FileTabooIssues(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    issues: issues
  ))}
  func reportReviewObsolete(
    files: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ReviewObsolete(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    files: files
  ))}
  func reportForbiddenCommits(
    commits: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ForbiddenCommits(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    commits: commits
  ))}
  func reportConflictMarkers(
    markers: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ConflictMarkers(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    markers: markers
  ))}
  func reportInvalidTitle(
    review: Json.GitlabReviewState
  ) -> Report { .init(cfg: self, reportable: Report.InvalidTitle(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: [review.author.username]
  ))}
  func reportReviewBlocked(
    review: Json.GitlabReviewState,
    users: [String],
    reasons: [Report.ReviewBlocked.Reason]
  ) -> Report { .init(cfg: self, reportable: Report.ReviewBlocked(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: .init(users)
      .union([review.author.username]),
    reasons: reasons
  ))}
  func reportReviewMergeConflicts(
    review: Json.GitlabReviewState,
    users: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ReviewMergeConflicts(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: .init(users)
      .union([review.author.username])
  ))}
  func reportReviewMerged(
    review: Json.GitlabReviewState,
    users: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ReviewMerged(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: .init(users)
      .union([review.author.username])
  ))}
  func reportReviewMergeError(
    review: Json.GitlabReviewState,
    users: [String],
    error: String
  ) -> Report { .init(cfg: self, reportable: Report.ReviewMergeError(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: .init(users)
      .union([review.author.username]),
    error: error
  ))}
  func reportEmergencyAwardApproval(
    review: Json.GitlabReviewState,
    users: Set<String>,
    cheaters: Set<String>
  ) -> Report { .init(cfg: self, reportable: Report.EmergencyAwardApproval(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users,
    cheaters: cheaters
  ))}
  func reportDoneAwardApproval(
    review: Json.GitlabReviewState,
    users: Set<String>
  ) -> Report { .init(cfg: self, reportable: Report.DoneAwardApproval(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users
  ))}
  func reportNewAwardApproval(
    review: Json.GitlabReviewState,
    users: Set<String>,
    group: AwardApproval.Group.Report
  ) -> Report { .init(cfg: self, reportable: Report.NewAwardApproval(
    event: "\(Report.NewAwardApproval.self)/\(group.name)",
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users,
    group: group
  ))}
  func reportWaitAwardApproval(
    review: Json.GitlabReviewState,
    users: Set<String>,
    group: AwardApproval.Group.Report
  ) -> Report { .init(cfg: self, reportable: Report.WaitAwardApproval(
    event: "\(Report.WaitAwardApproval.self)/\(group.name)",
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users,
    group: group
  ))}
  func reportNewAwardApprovals(
    review: Json.GitlabReviewState,
    users: Set<String>,
    groups: [AwardApproval.Group.Report]
  ) -> Report { .init(cfg: self, reportable: Report.NewAwardApprovals(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users,
    groups: groups
  ))}
  func reportWaitAwardApprovals(
    review: Json.GitlabReviewState,
    users: Set<String>,
    groups: [AwardApproval.Group.Report]
  ) -> Report { .init(cfg: self, reportable: Report.WaitAwardApprovals(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users,
    groups: groups
  ))}
  func reportAwardApprovalHolders(
    review: Json.GitlabReviewState,
    users: Set<String>,
    holders: Set<String>
  ) -> Report { .init(cfg: self, reportable: Report.AwardApprovalHolders(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users,
    holders: holders
  ))}
  func reportReleaseNotes(
    commits: [String]
  ) -> Report { .init(cfg: self, reportable: Report.ReleaseNotes(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    commits: commits
  ))}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) -> Report { .init(cfg: self, reportable: Report.ExpiringRequisites(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
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
