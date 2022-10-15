import Foundation
import Facility
public struct Report: Query {
  public var cfg: Configuration
  public var context: GenerationContext
  public struct CreateThread: Query {
    public var template: Configuration.Template
    public var report: Report
    public typealias Reply = Yaml.Thread
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
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
  }
  public struct ReviewMergeConflicts: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
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
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var reason: Reason
    public enum Reason: String, Encodable {
      case noSourceRule
      case targetNotProtected
      case targetNotDefault
      case authorNotBot
      case sourceNotProtected
      case forkInTarget
      case forkParentNotInTarget
      case forkNotInSource
      case forkNotInSupply
      case manual
    }
  }
  public struct ReviewBlocked: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
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
  public struct ReviewUnapprovable: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var inactiveAuthors: Bool
    public var unapprovableTeams: [String]?
  }
  public struct ReviewUpdate: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var teams: [String]?
    public var mentions: [String]?
    public var watchers: [String]?
    public var blockers: [String]?
    public var slackers: [String]?
    public var approvers: [String]?
    public var outdaters: [String: [String]]?
    public var state: Review.Approval.State
  }
  public struct ReviewMerged: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
  }
  public struct ReviewMergeError: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
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
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var authors: [String]
    public var slackers: [String]
  }
  public struct ReviewCustom: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var subevent: String
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
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
    public var ctx: AnyCodable? = nil
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
    public var ctx: AnyCodable? = nil
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
    public var ctx: AnyCodable? = nil
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
    public var ctx: AnyCodable? = nil
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
  public struct ReleaseCustom: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var subevent: String
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
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
    public var ctx: AnyCodable? = nil
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
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
    public var stdin: AnyCodable?
  }
  public struct Unexpected: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
    public var error: String
  }
  public struct AccessoryBranchCreated: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
    public var ref: String
  }
  public struct ExpiringRequisites: GenerationContext {
    public var event: String = Self.event
    public var mark: String? = nil
    public var env: [String: String] = [:]
    public var ctx: AnyCodable? = nil
    public var info: GitlabCi.Info? = nil
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
  func reportReviewCreated(
    fusion: Fusion,
    review: Json.GitlabReviewState,
    users: [String: Fusion.Approval.Approver],
    authors: Set<String>
  ) -> Report.CreateThread { .init(
    template: fusion.createThread,
    report: .init(cfg: self, context: Report.ReviewCreated(
      env: env,
      ctx: context,
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
  func reportReviewUnapprovable(
    review: Review,
    state: Json.GitlabReviewState,
    approval: Review.Approval
  ) -> Report { .init(cfg: self, context: Report.ReviewUnapprovable(
    thread: review.status.thread,
    review: state,
    users: review.approvers,
    authors: review.status.authors.sorted(),
    inactiveAuthors: approval.inactiveAuthors,
    unapprovableTeams: approval.unapprovableTeams.isEmpty.else(approval.unapprovableTeams.sorted())
  ))}
  func reportReviewUpdate(
    review: Review,
    state: Json.GitlabReviewState,
    update: Review.Approval
  ) -> Report { .init(cfg: self, context: Report.ReviewUpdate(
    thread: review.status.thread,
    review: state,
    users: review.approvers,
    authors: update.authors.sorted(),
    teams: update.teams.isEmpty.else(update.teams.sorted()),
    mentions: update.mentions.isEmpty.else(update.mentions.sorted()),
    watchers: update.watchers.isEmpty.else(update.watchers.sorted()),
    blockers: update.blockers.isEmpty.else(update.blockers.sorted()),
    slackers: update.slackers.isEmpty.else(update.slackers.sorted()),
    approvers: update.approvers.isEmpty.else(update.approvers.sorted()),
    outdaters: update.outdaters.isEmpty.else(update.outdaters.mapValues({ $0.sorted() })),
    state: update.state
  ))}
  func reportReviewMerged(
    review: Review,
    state: Json.GitlabReviewState
  ) -> Report { .init(cfg: self, context: Report.ReviewMerged(
    thread: review.status.thread,
    review: state,
    users: review.approvers,
    authors: review.status.authors.sorted()
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
  func reportReviewCustom(
    event: String,
    status: Fusion.Approval.Status,
    approvers: [String: Fusion.Approval.Approver],
    state: Json.GitlabReviewState,
    stdin: AnyCodable?
  ) -> Report { .init(cfg: self, context: Report.ReviewCustom(
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
      ctx: context,
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
  func reportReleaseCustom(
    event: String,
    product: Production.Product,
    delivery: Production.Version.Delivery,
    ref: String,
    sha: String,
    stdin: AnyCodable?
  ) -> Report { .init(cfg: self, context: Report.ReleaseCustom(
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
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) -> Report { .init(cfg: self, context: Report.ExpiringRequisites(
    items: items
  ))}
}
