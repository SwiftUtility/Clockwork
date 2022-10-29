import Foundation
import Facility
public struct Report: Query {
  public var cfg: Configuration
  public var context: GenerationContext
  public struct CreateThread: Query {
    public var template: Configuration.Template
    public var report: Report
    public typealias Reply = Configuration.Thread
  }
  public typealias Reply = Void
  public func generate(template: Configuration.Template) -> Generate { .init(
    allowEmpty: true,
    template: template,
    templates: cfg.templates,
    context: context
  )}
  public struct ReviewCreated: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
  }
  public struct ReviewMergeConflicts: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
  }
  public struct ReviewClosed: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var reason: Reason
    public enum Reason: String, Encodable {
      case authorIsBot
      case authorNotBot
      case noSourceRule
      case targetNotProtected
      case targetNotDefault
      case subjectNotProtected
      case sourceIsProtected
      case forkInTarget
      case forkParentNotInTarget
      case forkNotInSubject
      case forkNotInSource
      case manual
      public var logMessage: LogMessage {
        switch self {
        case .authorIsBot: return .init(message: "Author of proposition is bot")
        case .authorNotBot: return .init(message: "Author of merging is not bot")
        case .noSourceRule: return .init(message: "No rule for source branch")
        case .targetNotProtected: return .init(message: "Target branch is not protected")
        case .targetNotDefault: return .init(message: "Target branch is not default")
        case .subjectNotProtected: return .init(message: "Fork subject branch is not protected")
        case .sourceIsProtected: return .init(message: "Source branch is protected")
        case .forkInTarget: return .init(message: "Fork commit is already in target branch")
        case .forkParentNotInTarget: return .init(message: "Fork parent commit is not in target branch")
        case .forkNotInSubject: return .init(message: "Fork commit is not in fork subject branch")
        case .forkNotInSource: return .init(message: "Fork commit is not in source branch")
        case .manual: return .init(message: "Closed manually")
        }
      }
    }
  }
  public struct ReviewBlocked: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var reasons: [Reason]
    public var unknownUsers: [String]?
    public var unknownTeams: [String]?
    public enum Reason: String, Encodable {
      case draft
      case workInProgress
      case blockingDiscussions
      case squashStatus
      case badTarget
      case badTitle
      case extraCommits
      case taskMismatch
      case sanity
      case unknownTeams
      case unknownUsers
    }
  }
  public struct ReviewUpdated: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
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
    public var subevent: String { state.rawValue }
  }
  public struct ReviewMerged: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var teams: [String]?
    public var watchers: [String]?
    public var approvers: [String]?
    public var state: Review.Approval.State
    public var subevent: String { state.rawValue }
  }
  public struct ReviewMergeError: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var error: String
  }
  public struct ReviewRemind: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var slackers: [String]
  }
  public struct ReviewThread: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var subevent: String
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var stdin: AnyCodable?
  }
  public struct ReleaseBranchCreated: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var ref: String
    public var product: String
    public var version: String
    public var hotfix: Bool
    public var subevent: String { product }
  }
  public struct ReleaseBranchDeleted: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var revoke: Bool
    public var subevent: String { product }
  }
  public struct ReleaseBranchSummary: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var notes: Production.ReleaseNotes?
    public var subevent: String { product }
  }
  public struct DeployTagCreated: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var build: String
    public var notes: Production.ReleaseNotes?
    public var subevent: String { product }
  }
  public struct ReleaseThread: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var subevent: String
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var stdin: AnyCodable?
  }
  public struct StageTagCreated: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var build: String
    public var subevent: String { product }
  }
  public struct StageTagDeleted: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var ref: String
    public var sha: String
    public var product: String
    public var version: String
    public var build: String
    public var subevent: String { product }
  }
  public struct Custom: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var subevent: String
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var stdin: AnyCodable?
  }
  public struct Unexpected: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var error: String
  }
  public struct AccessoryBranchCreated: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var ref: String
  }
  public struct AccessoryBranchDeleted: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
    public var ref: String
  }
  public struct ExpiringRequisites: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var info: GitlabCi.Info? = nil
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
public extension Configuration {
  func reportReviewCreated(
    fusion: Fusion,
    review: Json.GitlabReviewState,
    users: [String: Fusion.Approval.Approver],
    authors: Set<String>
  ) -> Report.CreateThread { .init(
    template: fusion.createThread,
    report: .init(cfg: self, context: Report.ReviewCreated(
      env: env,
      info: try? gitlabCi.get().info,
      review: review,
      users: users,
      authors: authors.sorted()
    ))
  )}
  func reportReviewMergeConflicts(
    review: Review,
    state: Json.GitlabReviewState
  ) -> Report { .init(cfg: self, context: Report.ReviewMergeConflicts(
    thread: review.status.thread,
    review: state,
    users: review.approvers,
    authors: review.status.authors.sorted()
  ))}
  func reportReviewClosed(
    status: Fusion.Approval.Status,
    state: Json.GitlabReviewState,
    users: [String: Fusion.Approval.Approver],
    reason: Report.ReviewClosed.Reason
  ) -> Report { .init(cfg: self, context: Report.ReviewClosed(
    thread: status.thread,
    review: state,
    users: users,
    authors: status.authors.sorted(),
    reason: reason
  ))}
  func reportReviewBlocked(
    review: Review,
    state: Json.GitlabReviewState,
    reasons: [Report.ReviewBlocked.Reason]
  ) -> Report { .init(cfg: self, context: Report.ReviewBlocked(
    thread: review.status.thread,
    review: state,
    users: review.approvers,
    authors: review.status.authors.sorted(),
    reasons: reasons,
    unknownUsers: review.unknownUsers.isEmpty.else(review.unknownUsers.sorted()),
    unknownTeams: review.unknownTeams.isEmpty.else(review.unknownTeams.sorted())
  ))}
  func reportReviewUpdate(
    review: Review,
    state: Json.GitlabReviewState,
    update: Review.Approval
  ) -> Report { .init(cfg: self, context: Report.ReviewUpdated(
    thread: review.status.thread,
    review: state,
    users: review.approvers,
    authors: review.status.authors.sorted(),
    teams: review.status.teams.isEmpty.else(review.status.teams.sorted()),
    watchers: review.watchers,
    blockers: update.blockers.isEmpty.else(update.blockers.sorted()),
    slackers: update.slackers.isEmpty.else(update.slackers.sorted()),
    approvers: update.approvers.isEmpty.else(update.approvers.sorted()),
    outdaters: update.outdaters.isEmpty.else(update.outdaters.mapValues({ $0.sorted() })),
    orphaned: update.orphaned,
    unapprovable: update.unapprovable.isEmpty.else(update.unapprovable.sorted()),
    state: update.state
  ))}
  func reportReviewMerged(
    review: Review,
    state: Json.GitlabReviewState
  ) -> Report { .init(cfg: self, context: Report.ReviewMerged(
    thread: review.status.thread,
    review: state,
    users: review.approvers,
    authors: review.status.authors.sorted(),
    teams: review.status.teams.isEmpty.else(review.status.teams.sorted()),
    watchers: review.watchers,
    approvers: review.status.participants.isEmpty.else(review.status.participants.sorted()),
    state: review.status.emergent.map({_ in .emergent}).get(.approved)
  ))}
  func reportReviewMergeError(
    review: Review,
    state: Json.GitlabReviewState,
    error: String
  ) -> Report { .init(cfg: self, context: Report.ReviewMergeError(
    thread: review.status.thread,
    review: state,
    users: review.approvers,
    authors: review.status.authors.sorted(),
    error: error
  ))}
  func reportReviewRemind(
    approvers: [String: Fusion.Approval.Approver],
    status: Fusion.Approval.Status,
    state: Json.GitlabReviewState,
    slackers: Set<String>
  ) -> Report { .init(cfg: self, context: Report.ReviewRemind(
    thread: status.thread,
    review: state,
    users: approvers,
    authors: status.authors.sorted(),
    slackers: slackers.sorted()
  ))}
  func reportReviewThread(
    event: String,
    status: Fusion.Approval.Status,
    approvers: [String: Fusion.Approval.Approver],
    state: Json.GitlabReviewState,
    stdin: AnyCodable?
  ) -> Report { .init(cfg: self, context: Report.ReviewThread(
    subevent: event,
    thread: status.thread,
    review: state,
    users: approvers,
    authors: status.authors.sorted(),
    stdin: stdin
  ))}
  func reportReleaseBranchCreated(
    product: Production.Product,
    ref: String,
    version: String,
    hotfix: Bool
  ) -> Report.CreateThread { .init(
    template: product.createReleaseThread,
    report: .init(cfg: self, context: Report.ReleaseBranchCreated(
      env: env,
      info: try? gitlabCi.get().info,
      ref: ref,
      product: product.name,
      version: version,
      hotfix: hotfix
    ))
  )}
  func reportReleaseBranchDeleted(
    product: Production.Product,
    delivery: Production.Version.Delivery,
    ref: String,
    sha: String,
    revoke: Bool
  ) -> Report { .init(cfg: self, context: Report.ReleaseBranchDeleted(
    thread: delivery.thread,
    ref: ref,
    sha: sha,
    product: product.name,
    version: delivery.version.value,
    revoke: revoke
  ))}
  func reportReleaseBranchSummary(
    product: Production.Product,
    delivery: Production.Version.Delivery,
    ref: String,
    sha: String,
    notes: Production.ReleaseNotes
  ) -> Report { .init(cfg: self, context: Report.ReleaseBranchSummary(
    thread: delivery.thread,
    ref: ref,
    sha: sha,
    product: product.name,
    version: delivery.version.value,
    notes: notes.isEmpty.else(notes)
  ))}
  func reportDeployTagCreated(
    product: Production.Product,
    delivery: Production.Version.Delivery,
    ref: String,
    sha: String,
    build: String,
    notes: Production.ReleaseNotes
  ) -> Report { .init(cfg: self, context: Report.DeployTagCreated(
    thread: delivery.thread,
    ref: ref,
    sha: sha,
    product: product.name,
    version: delivery.version.value,
    build: build,
    notes: notes.isEmpty.else(notes)
  ))}
  func reportReleaseThread(
    event: String,
    product: Production.Product,
    delivery: Production.Version.Delivery,
    ref: String,
    sha: String,
    stdin: AnyCodable?
  ) -> Report { .init(cfg: self, context: Report.ReleaseThread(
    subevent: event,
    thread: delivery.thread,
    ref: ref,
    sha: sha,
    product: product.name,
    version: delivery.version.value,
    stdin: stdin
  ))}
  func reportStageTagCreated(
    product: Production.Product,
    ref: String,
    sha: String,
    version: String,
    build: String
  ) -> Report { .init(cfg: self, context: Report.StageTagCreated(
    ref: ref,
    sha: sha,
    product: product.name,
    version: version,
    build: build
  ))}
  func reportStageTagDeleted(
    product: Production.Product,
    ref: String,
    sha: String,
    version: String,
    build: String
  ) -> Report { .init(cfg: self, context: Report.StageTagDeleted(
    ref: ref,
    sha: sha,
    product: product.name,
    version: version,
    build: build
  ))}
  func reportCustom(
    event: String,
    stdin: AnyCodable?
  ) -> Report { .init(cfg: self, context: Report.Custom(
    subevent: event,
    stdin: stdin
  ))}
  func reportUnexpected(
    error: Error
  ) -> Report { .init(cfg: self, context: Report.Unexpected(
    error: String(describing: error)
  ))}
  func reportAccessoryBranchCreated(
    ref: String
  ) -> Report { .init(cfg: self, context: Report.AccessoryBranchCreated(
    ref: ref
  ))}
  func reportAccessoryBranchDeleted(
    ref: String
  ) -> Report { .init(cfg: self, context: Report.AccessoryBranchDeleted(
    ref: ref
  ))}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) -> Report { .init(cfg: self, context: Report.ExpiringRequisites(
    items: items
  ))}
}
