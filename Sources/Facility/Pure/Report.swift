import Foundation
import Facility
public protocol ReportContext: GenerateContext {}
public extension ReportContext {
  static var allowEmpty: Bool { true }
}
public struct Report: Query {
  public var cfg: Configuration
  public var info: GenerateInfo
  public init<Context: ReportContext>(
    cfg: Configuration,
    ctx: Context,
    subevent: [String]? = nil
  ) {
    self.cfg = cfg
    self.info = Generate.Info.make(context: ctx, subevent: subevent.get(ctx.subevent))
  }
  public func generate(template: Configuration.Template) -> Generate {
    .init(template: template, templates: cfg.templates, info: info)
  }
  public typealias Reply = Void
//  public struct Threads {
//    public var gitlab: Gitlab?
//    public var jira: Jira?
//    public struct Gitlab {
//      public var tag: String?
//      public var review: UInt?
//      public var branch: String?
//    }
//    public struct Jira {
//      public var tasks: [String]?
//      public var epics: [String]?
//    }
//  }
  public struct ReviewCreated: ReportContext {
    public var authors: [String]
  }
  public struct ReviewMergeConflicts: ReportContext {
    public var authors: [String]
  }
  public struct ReviewClosed: ReportContext {
    public var authors: [String]
  }
  public struct ReviewBlocked: ReportContext {
    public var authors: [String]
    public var reasons: [Reason]
    public var unknownUsers: [String]?
    public var unknownTeams: [String]?
    public enum Reason: String, Encodable {
      case authorIsBot
      case authorNotBot
      case badTitle
      case draft
      case discussions
      case extraCommits
      case forkInTarget
      case forkNotInSource
      case forkNotInSubject
      case forkParentNotInTarget
      case forkTargetMismatch
      case noSourceRule
      case targetNotDefault
      case targetNotProtected
      case taskMismatch
      case sanity
      case sourceIsProtected
      case squashStatus
      case subjectNotProtected
      case unknownTeams
      case unknownUsers
      case workInProgress
      public var logMessage: LogMessage {
        switch self {
        case .authorIsBot: return .init(message: "Author of proposition is bot")
        case .authorNotBot: return .init(message: "Author of merging is not bot")
        case .badTitle: return .init(message: "Title does not match rule criteria")
        case .draft: return .init(message: "Merge request is in draft state")
        case .discussions: return .init(message: "Merge request has unresolved discussions")
        case .extraCommits: return .init(message: "Source branch contains non protected commits")
        case .forkInTarget: return .init(message: "Fork commit is already in target branch")
        case .forkNotInSource: return .init(message: "Fork commit is not in source branch")
        case .forkNotInSubject: return .init(message: "Fork commit is not in fork subject branch")
        case .forkParentNotInTarget: return .init(message: "Fork parent commit is not in target branch")
        case .forkTargetMismatch: return .init(message: "Fork target branch changed")
        case .noSourceRule: return .init(message: "No rule for source branch")
        case .targetNotDefault: return .init(message: "Target branch is not default")
        case .targetNotProtected: return .init(message: "Target branch is not protected")
        case .taskMismatch: return .init(message: "Branch name and title contain different tasks")
        case .sanity: return .init(message: "Sanity group does not track approval configuration")
        case .sourceIsProtected: return .init(message: "Source branch is protected")
        case .squashStatus: return .init(message: "Bad merge request squash status")
        case .subjectNotProtected: return .init(message: "Fork subject branch is not protected")
        case .unknownTeams: return .init(message: "Found not configured teams")
        case .unknownUsers: return .init(message: "Found not registered users")
        case .workInProgress: return .init(message: "Merge request is in WIP state")
        }
      }
    }
  }
  public struct ReviewUpdated: ReportContext {
    public var authors: [String]
    public var teams: [String]?
    public var watchers: [String]?
    public var blockers: [String]?
    public var slackers: [String]?
    public var approvers: [String]?
    public var outdaters: [String: [String]]?
    public var orphaned: Bool
    public var unapprovable: [String]?
    public var state: Review.Approval.State
    public var subevent: [String] { [state.rawValue] }
  }
  public struct ReviewMerged: ReportContext {
    public var authors: [String]
    public var teams: [String]?
    public var watchers: [String]?
    public var approvers: [String]?
    public var state: Review.Approval.State
    public var subevent: [String] { [state.rawValue] }
  }
  public struct ReviewMergeError: ReportContext {
    public var authors: [String]
    public var error: String
  }
  public struct ReviewRemind: ReportContext {
    public var authors: [String]
    public var slackers: [String]
  }
  public struct ReviewCustom: ReportContext {
    public var authors: [String]
    public var stdin: AnyCodable?
  }
  public struct ReleaseBranchCreated: ReportContext {
    public var ref: String
    public var product: String
    public var version: String
    public var hotfix: Bool
    public var subevent: [String] { [product] }
  }
  public struct ReleaseBranchDeleted: ReportContext {
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var revoke: Bool
    public var subevent: [String] { [product] }
  }
  public struct ReleaseBranchSummary: ReportContext {
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var notes: Production.ReleaseNotes?
    public var subevent: [String] { [product] }
  }
  public struct DeployTagCreated: ReportContext {
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var build: String
    public var notes: Production.ReleaseNotes?
    public var subevent: [String] { [product] }
  }
  public struct ReleaseCustom: ReportContext {
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var stdin: AnyCodable?
  }
  public struct StageTagCreated: ReportContext {
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var build: String
    public var subevent: [String] { [product] }
  }
  public struct StageTagDeleted: ReportContext {
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var build: String
    public var subevent: [String] { [product] }
  }
  public struct Custom: ReportContext {
    public var stdin: AnyCodable?
  }
  public struct Unexpected: ReportContext {
    public var error: String
  }
  public struct AccessoryBranchCreated: ReportContext {
    public var ref: String
  }
  public struct AccessoryBranchDeleted: ReportContext {
    public var ref: String
  }
  public struct ExpiringRequisites: ReportContext {
    public var items: [Item]
    public struct Item: Encodable {
      public var file: String
      public var branch: String
      public var name: String
      public var days: String?
      public init(file: String, branch: String, name: String, days: TimeInterval) {
        self.file = file
        self.branch = branch
        self.name = name
        if days > 0 { self.days = "\(Int(days))" }
      }
    }
  }
}
public extension Fusion.Approval.Status {
  func reportReviewCreated(cfg: Configuration) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReviewCreated(authors: authors.sorted())
  )}
  func reportReviewMergeConflicts(cfg: Configuration) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReviewMergeConflicts(authors: authors.sorted())
  )}
  func reportReviewClosed(cfg: Configuration) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReviewClosed(authors: authors.sorted())
  )}
  func reportReviewRemind(cfg: Configuration, slackers: Set<String>) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReviewRemind(
      authors: authors.sorted(),
      slackers: slackers.sorted()
    )
  )}
  func reportReviewCustom(
    cfg: Configuration,
    event: String,
    stdin: AnyCodable?
  ) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReviewCustom(
      authors: authors.sorted(),
      stdin: stdin
    ),
    subevent: event.components(separatedBy: "/")
  )}
}
public extension Review {
  func reportReviewBlocked(
    cfg: Configuration,
    reasons: [Report.ReviewBlocked.Reason]
  ) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReviewBlocked(
      authors: status.authors.sorted(),
      reasons: reasons,
      unknownUsers: unknownUsers.isEmpty.else(unknownUsers.sorted()),
      unknownTeams: unknownTeams.isEmpty.else(unknownTeams.sorted())
    )
  )}
  func reportReviewUpdated(cfg: Configuration, update: Review.Approval) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReviewUpdated(
      authors: status.authors.sorted(),
      teams: status.teams.isEmpty.else(status.teams.sorted()),
      watchers: watchers,
      blockers: update.blockers.isEmpty.else(update.blockers.sorted()),
      slackers: update.slackers.isEmpty.else(update.slackers.sorted()),
      approvers: update.approvers.isEmpty.else(update.approvers.sorted()),
      outdaters: update.outdaters.isEmpty.else(update.outdaters.mapValues({ $0.sorted() })),
      orphaned: update.orphaned,
      unapprovable: update.unapprovable.isEmpty.else(update.unapprovable.sorted()),
      state: update.state
    )
  )}
  func reportReviewMerged(cfg: Configuration) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReviewMerged(
      authors: status.authors.sorted(),
      teams: status.teams.isEmpty.else(status.teams.sorted()),
      watchers: watchers,
      approvers: accepters,
      state: status.emergent
        .map({_ in .emergent})
        .get(.approved)
    )
  )}
  func reportReviewMergeError(cfg: Configuration, error: String) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReviewMergeError(
      authors: status.authors.sorted(),
      error: error
    )
  )}
}
public extension Production.Product {
  func reportReleaseBranchCreated(
    cfg: Configuration,
    ref: String,
    version: String,
    hotfix: Bool
  ) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReleaseBranchCreated(
      ref: ref,
      product: name,
      version: version,
      hotfix: hotfix
    )
  )}
  func reportReleaseBranchDeleted(
    cfg: Configuration,
    delivery: Production.Version.Delivery,
    ref: String,
    sha: String,
    revoke: Bool
  ) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReleaseBranchDeleted(
      ref: ref,
      sha: sha,
      product: name,
      version: delivery.version.value,
      revoke: revoke
    )
  )}
  func reportReleaseBranchSummary(
    cfg: Configuration,
    delivery: Production.Version.Delivery,
    ref: String,
    sha: String,
    notes: Production.ReleaseNotes
  ) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReleaseBranchSummary(
      ref: ref,
      sha: sha,
      product: name,
      version: delivery.version.value,
      notes: notes.isEmpty.else(notes)
    )
  )}
  func reportDeployTagCreated(
    cfg: Configuration,
    delivery: Production.Version.Delivery,
    ref: String,
    sha: String,
    build: String,
    notes: Production.ReleaseNotes
  ) -> Report { .init(
    cfg: cfg,
    ctx: Report.DeployTagCreated(
      ref: ref,
      sha: sha,
      product: name,
      version: delivery.version.value,
      build: build,
      notes: notes.isEmpty.else(notes)
    )
  )}
  func reportReleaseCustom(
    cfg: Configuration,
    event: String,
    delivery: Production.Version.Delivery,
    ref: String,
    sha: String,
    stdin: AnyCodable?
  ) -> Report { .init(
    cfg: cfg,
    ctx: Report.ReleaseCustom(
      ref: ref,
      sha: sha,
      product: name,
      version: delivery.version.value,
      stdin: stdin
    ),
    subevent: event.components(separatedBy: "/")
  )}
  func reportStageTagCreated(
    cfg: Configuration,
    ref: String,
    sha: String,
    version: String,
    build: String
  ) -> Report { .init(
    cfg: cfg,
    ctx: Report.StageTagCreated(
      ref: ref,
      sha: sha,
      product: name,
      version: version,
      build: build
    )
  )}
  func reportStageTagDeleted(
    cfg: Configuration,
    ref: String,
    sha: String,
    version: String,
    build: String
  ) -> Report { .init(
    cfg: cfg,
    ctx: Report.StageTagDeleted(
      ref: ref,
      sha: sha,
      product: name,
      version: version,
      build: build
    )
  )}
}
public extension Configuration {
  func reportCustom(
    event: String,
    stdin: AnyCodable?
  ) -> Report { .init(
    cfg: self,
    ctx: Report.Custom(stdin: stdin),
    subevent: event.components(separatedBy: "/")
  )}
  func reportUnexpected(
    error: Error
  ) -> Report { .init(
    cfg: self,
    ctx: Report.Unexpected(error: String(describing: error))
  )}
  func reportAccessoryBranchCreated(ref: String) -> Report { .init(
    cfg: self,
    ctx: Report.AccessoryBranchCreated(ref: ref)
  )}
  func reportAccessoryBranchDeleted(ref: String) -> Report { .init(
    cfg: self,
    ctx: Report.AccessoryBranchDeleted(ref: ref)
  )}
  func reportExpiringRequisites(items: [Report.ExpiringRequisites.Item]) -> Report { .init(
    cfg: self,
    ctx: Report.ExpiringRequisites(items: items)
  )}
}
