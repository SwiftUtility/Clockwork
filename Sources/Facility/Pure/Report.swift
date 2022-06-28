import Foundation
import Facility
public struct Report: Query {
  public var cfg: Configuration
  public var context: GenerationContext
  public typealias Reply = Void
  public struct Custom: GenerationContext {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var stdin: [String]
  }
  public struct Unexpected: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var error: String
  }
  public struct UnownedCode: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var files: [String]
  }
  public struct FileTaboos: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var issues: [FileTaboo.Issue]
  }
  public struct ReviewObsolete: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var files: [String]?
  }
  public struct ForbiddenCommits: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var commits: [String]?
  }
  public struct ConflictMarkers: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var markers: [String]
  }
  public struct InvalidTitle: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewBlocked: GenerationContext {
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
  public struct ReviewMergeConflicts: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewMerged: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewMergeError: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var error: String
  }
  public struct EmergencyAwardApproval: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var cheaters: Set<String>
  }
  public struct AwardApprovalReady: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct NewAwardApproval: GenerationContext {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var group: AwardApproval.Group.Report
  }
  public struct WaitAwardApproval: GenerationContext {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var group: AwardApproval.Group.Report
  }
  public struct NewAwardApprovals: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var groups: [AwardApproval.Group.Report]
  }
  public struct WaitAwardApprovals: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var groups: [AwardApproval.Group.Report]
  }
  public struct AwardApprovalHolders: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var holders: Set<String>
  }
  public struct ReleaseNotes: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var commits: [String]
  }
  public struct Release: GenerationContext {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
    public var product: String
    public var version: String
  }
  public struct Hotfix: GenerationContext {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
    public var product: String
    public var version: String
  }
  public struct Deploy: GenerationContext {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var deploy: Production.Build.Deploy
    public var uniq: [Commit]?
    public var heir: [Commit]?
    public var lack: [Commit]?
    public struct Commit: Encodable {
      public var sha: String
      public var msg: String
      public static func make(sha: String, msg: String) -> Self { .init(sha: sha, msg: msg) }
    }
  }
  public struct Version: GenerationContext {
    public let event: String
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct Accessory: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
  }
  public struct ExpiringRequisites: GenerationContext {
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
  ) -> Report { .init(cfg: self, context: Report.Custom(
    event: "\(Report.Custom.event)/\(event)",
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    stdin: stdin
  ))}
  func reportUnexpected(
    error: Error
  ) -> Report { .init(cfg: self, context: Report.Unexpected(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    error: verbose.then(String(reflecting: error)).get(String(describing: error))
  ))}
  func reportUnownedCode(
    files: [String]
  ) -> Report { .init(cfg: self, context: Report.UnownedCode(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    files: files
  ))}
  func reportFileTaboos(
    issues: [FileTaboo.Issue]
  ) -> Report { .init(cfg: self, context: Report.FileTaboos(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    issues: issues
  ))}
  func reportReviewObsolete(
    files: [String]
  ) -> Report { .init(cfg: self, context: Report.ReviewObsolete(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    files: files
  ))}
  func reportForbiddenCommits(
    commits: [String]
  ) -> Report { .init(cfg: self, context: Report.ForbiddenCommits(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    commits: commits
  ))}
  func reportConflictMarkers(
    markers: [String]
  ) -> Report { .init(cfg: self, context: Report.ConflictMarkers(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    markers: markers
  ))}
  func reportInvalidTitle(
    review: Json.GitlabReviewState
  ) -> Report { .init(cfg: self, context: Report.InvalidTitle(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: [review.author.username]
  ))}
  func reportReviewBlocked(
    review: Json.GitlabReviewState,
    users: [String],
    reasons: [Report.ReviewBlocked.Reason]
  ) -> Report { .init(cfg: self, context: Report.ReviewBlocked(
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
  ) -> Report { .init(cfg: self, context: Report.ReviewMergeConflicts(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: .init(users)
      .union([review.author.username])
  ))}
  func reportReviewMerged(
    review: Json.GitlabReviewState,
    users: [String]
  ) -> Report { .init(cfg: self, context: Report.ReviewMerged(
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
  ) -> Report { .init(cfg: self, context: Report.ReviewMergeError(
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
  ) -> Report { .init(cfg: self, context: Report.EmergencyAwardApproval(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users,
    cheaters: cheaters
  ))}
  func reportAwardApprovalReady(
    review: Json.GitlabReviewState,
    users: Set<String>
  ) -> Report { .init(cfg: self, context: Report.AwardApprovalReady(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users
  ))}
  func reportNewAwardApproval(
    review: Json.GitlabReviewState,
    users: Set<String>,
    group: AwardApproval.Group.Report
  ) -> Report { .init(cfg: self, context: Report.NewAwardApproval(
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
  ) -> Report { .init(cfg: self, context: Report.WaitAwardApproval(
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
  ) -> Report { .init(cfg: self, context: Report.NewAwardApprovals(
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
  ) -> Report { .init(cfg: self, context: Report.WaitAwardApprovals(
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
  ) -> Report { .init(cfg: self, context: Report.AwardApprovalHolders(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    review: review,
    users: users,
    holders: holders
  ))}
  func reportReleaseNotes(
    commits: [String]
  ) -> Report { .init(cfg: self, context: Report.ReleaseNotes(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    commits: commits
  ))}
  func reportRelease(
    ref: String,
    product: String,
    version: String
  ) -> Report { .init(cfg: self, context: Report.Release(
    event: "\(Report.Release.event)/\(product)",
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    ref: ref,
    product: product,
    version: version
  ))}
  func reportHotfix(
    ref: String,
    product: String,
    version: String
  ) -> Report { .init(cfg: self, context: Report.Hotfix(
    event: "\(Report.Hotfix.event)/\(product)",
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    ref: ref,
    product: product,
    version: version
  ))}
  func reportDeploy(
    deploy: Production.Build.Deploy,
    uniq: [Report.Deploy.Commit],
    heir: [Report.Deploy.Commit],
    lack: [Report.Deploy.Commit]
  ) -> Report { .init(cfg: self, context: Report.Deploy(
    event: "\(Report.Deploy.event)/\(deploy.product)",
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    deploy: deploy,
    uniq: uniq.isEmpty.else(uniq),
    heir: heir.isEmpty.else(heir),
    lack: lack.isEmpty.else(lack)
  ))}
  func reportVersion(
    product: String,
    version: String
  ) -> Report { .init(cfg: self, context: Report.Version(
    event: "\(Report.Version.event)/\(product)",
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    product: product,
    version: version
  ))}
  func reportAccessory(
    ref: String
  ) -> Report { .init(cfg: self, context: Report.Accessory(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    ref: ref
  ))}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) -> Report { .init(cfg: self, context: Report.ExpiringRequisites(
    ctx: controls.context,
    info: try? controls.gitlabCi.get().info,
    items: items
  ))}
}
extension Configuration.Controls {
  public func generateReport(
    template: Configuration.Template,
    context: GenerationContext
  ) -> Generate { .init(
    allowEmpty: true,
    template: template,
    templates: templates,
    context: context
  )}
}
