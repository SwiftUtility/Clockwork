import Foundation
import Facility
public protocol ReportContext: GenerateContext {}
public extension ReportContext {
  static var allowEmpty: Bool { true }
}
public struct Report: Query {
  public var cfg: Configuration
  public var threads: Threads
  public var info: GenerateInfo
  public static func make<Context: ReportContext>(
    cfg: Configuration,
    threads: Threads,
    ctx: Context,
    subevent: [String]? = nil,
    args: [String]? = nil,
    merge: Json.GitlabMergeState? = nil
  ) -> Self { .init(
    cfg: cfg,
    threads: threads,
    info: Generate.Info.make(cfg: cfg, context: ctx, args: args, subevent: subevent, merge: merge)
  )}
  public func generate(template: Configuration.Template) -> Generate {
    .init(template: template, templates: cfg.templates, info: info)
  }
  public typealias Reply = Void
  public struct Threads {
    public var tags: Set<String> = []
    public var users: Set<String> = []
    public var issues: Set<String> = []
    public var reviews: Set<UInt> = []
    public var branches: Set<String> = []
    public static func make(
      stage: Flow.Product.Stage
    ) -> Self { .init(
      tags: [stage.tag.name],
      branches: Set(stage.branch.array.map(\.name))
    )}
  }
  public enum Notify: String, ReportContext {
    case pipelineOutdated
    case reviewQueued
    case ownFailed
    case unownFailed
    case approveFailed
    case skipFailed
    case rebaseBlocked
    case patchFailed
    case propogationFailed
    case integrationFailed
    case duplicationFailed
    case replicationFailed
    case nothingToApprove
    public static func make(prefix: Review.Fusion.Prefix) -> Self {
      switch prefix {
      case .replicate: return .replicationFailed
      case .integrate: return .integrationFailed
      case .duplicate: return .duplicationFailed
      case .propogate: return .propogationFailed
      }
    }
  }
  public struct ReviewList: ReportContext {
    public var reviews: [UInt: ReviewApprove]
  }
  public struct ReviewApprove: ReportContext {
    public var diff: String?
    public var reason: Reason
    public enum Reason: String, Encodable {
      case remind
      case change
      case create
    }
  }
  public struct ReviewEvent: ReportContext {
    public var authors: [String]?
    public var iid: UInt
    public var reason: Reason
    public enum Reason: String, Encodable {
      case closed
      case merged
      case foremost
      case enqueued
      case dequeued
      case emergent
      case tranquil
    }
  }
  public struct ReviewMergeError: ReportContext {
    public var authors: [String]
    public var error: String
  }
  public struct ReviewUpdated: ReportContext {
    public var authors: [String]?
    public var teams: [String]?
    public var watchers: [String]?
    public var approvers: [Approver]? = nil
    public var problems: Problems? = nil
    public var ready: Bool = false
    public var amend: Bool = false
    public var block: Bool = false
    public var alarm: Bool = false
    public mutating func change(state: Review.State) {
      switch state.phase {
      case .block: block = true
      case .ready:
        if state.emergent == nil { ready = true } else { alarm = true }
      default: amend = true
      }
    }
    public struct Approver: Encodable {
      public var login: String
      public var miss: Bool
      public var fragil: Bool = false
      public var advance: Bool = false
      public var diff: String? = nil
      public var hold: Bool = false
      public var comments: Int? = nil
      static func present(reviewer: Review.Approve) -> Self { .init(
        login: reviewer.login,
        miss: false,
        fragil: reviewer.resolution.fragil,
        advance: reviewer.resolution.approved && reviewer.resolution.fragil.not,
        diff: reviewer.resolution.approved.not.then(reviewer.commit.value)
      )}
    }
    public struct Problems: Encodable {
      public var badSource: String? = nil
      public var targetNotProtected: Bool = false
      public var targetMismatch: String? = nil
      public var sourceIsProtected: Bool = false
      public var multipleKinds: [String]? = nil
      public var undefinedKind: Bool = false
      public var authorIsBot: Bool = false
      public var authorIsNotBot: String? = nil
      public var sanity: String? = nil
      public var extraCommits: [String]? = nil
      public var notCherry: Bool = false
      public var notForward: Bool = false
      public var forkInTarget: Bool = false
      public var forkNotProtected: Bool = false
      public var forkNotInSource: Bool = false
      public var forkParentNotInTarget: Bool = false
      public var sourceNotAtFrok: Bool = false
      public var conflicts: Bool = false
      public var squashCheck: Bool = false
      public var draft: Bool = false
      public var discussions: Bool = false
      public var badTitle: Bool = false
      public var taskMismatch: Bool = false
      public var holders: Bool = false
      public var unknownUsers: [String]? = nil
      public var unknownTeams: [String]? = nil
      public var confusedTeams: [String]? = nil
      public var orphaned: [String]? = nil
      public var unapprovableTeams: [String]? = nil
      mutating func register(problem: Review.Problem) {
        switch problem {
        case .badSource(let value): badSource = value
        case .targetNotProtected: targetNotProtected = true
        case .targetMismatch(let value): targetMismatch = value.name
        case .sourceIsProtected: sourceIsProtected = true
        case .multipleKinds(let value): multipleKinds = value.sortedNonEmpty
        case .undefinedKind: undefinedKind = true
        case .authorIsBot: authorIsBot = true
        case .authorIsNotBot(let value): authorIsNotBot = value
        case .sanity(let value): sanity = value
        case .extraCommits(let value): extraCommits = value.map(\.name).sortedNonEmpty
        case .notCherry: notCherry = true
        case .notForward: notForward = true
        case .forkInTarget: forkInTarget = true
        case .forkNotProtected: forkNotProtected = true
        case .forkNotInSource: forkNotInSource = true
        case .forkParentNotInTarget: forkParentNotInTarget = true
        case .sourceNotAtFrok: sourceNotAtFrok = true
        case .conflicts: conflicts = true
        case .squashCheck: squashCheck = true
        case .draft: draft = true
        case .discussions: discussions = true
        case .badTitle: badTitle = true
        case .taskMismatch: taskMismatch = true
        case .holders: holders = true
        case .unknownUsers(let value): unknownUsers = value.sortedNonEmpty
        case .unknownTeams(let value): unknownTeams = value.sortedNonEmpty
        case .confusedTeams(let value): confusedTeams = value.sortedNonEmpty
        case .orphaned(let value): orphaned = value.sortedNonEmpty
        case .unapprovableTeams(let value): unapprovableTeams = value.sortedNonEmpty
        }
      }
    }
  }
  public struct ReviewCustom: ReportContext {
    public var authors: [String]
    public var stdin: AnyCodable?
  }
  public struct ReleaseBranchCreated: ReportContext {
    public var product: String
    public var version: String
    public var hotfix: Bool
    public var subevent: [String] { [product] }
  }
  public struct ReleaseBranchDeleted: ReportContext {
    public var product: String
    public var version: String
    public var subevent: [String] { [product] }
  }
  public struct ReleaseBranchSummary: ReportContext {
    public var product: String
    public var version: String
    public var notes: Flow.ReleaseNotes?
    public var subevent: [String] { [product] }
  }
  public struct DeployTagCreated: ReportContext {
    public var product: String
    public var version: String
    public var build: String?
    public var notes: Flow.ReleaseNotes?
    public var subevent: [String] { [product] }
  }
  public struct ReleaseCustom: ReportContext {
    public var product: String
    public var version: String
    public var stdin: AnyCodable?
  }
  public struct StageTagCreated: ReportContext {
    public var product: String
    public var version: String
    public var build: String
    public var subevent: [String] { [product] }
  }
  public struct StageTagDeleted: ReportContext {
    public var product: String
    public var version: String
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
public extension Configuration {
//  func reportReviewCreated(
//    status: Fusion.Approval.Status,
//    review: Json.GitlabReviewState?
//  ) -> Report { .make(
//    cfg: self,
//    threads: makeThread(review: review, status: status, infusion: nil),
//    ctx: Report.ReviewCreated(authors: status.authors.sorted()),
//    review: review
//  )}
//  func reportReviewMergeConflicts(
//    status: Fusion.Approval.Status
//  ) -> Report { .make(
//    cfg: self,
//    threads: makeThread(review: nil, status: status, infusion: nil),
//    ctx: Report.ReviewMergeConflicts(authors: status.authors.sorted())
//  )}
  func report(
    notify: Report.Notify,
    user: String? = nil,
    merge: Json.GitlabMergeState? = nil
  ) -> Report {
    let user = user ?? (try? gitlab.map(\.job.user.username).get())
    return .make(
      cfg: self,
      threads: .init(users: Set(user.array), reviews: Set(merge.array.map(\.iid))),
      ctx: notify,
      subevent: [notify.rawValue],
      merge: merge
    )
  }
  func reportReviewList(
    user: String,
    reviews: [UInt: Report.ReviewApprove]
  ) -> Report { .make(
    cfg: self,
    threads: .init(users: [user]),
    ctx: Report.ReviewList(reviews: reviews)
  )}
  func reportReviewApprove(
    user: String,
    merge: Json.GitlabMergeState,
    approve: Report.ReviewApprove
  ) -> Report { .make(
    cfg: self,
    threads: .init(users: [user], reviews: [merge.iid]),
    ctx: approve,
    merge: merge
  )}
  func reportReviewEvent(
    state: Review.State,
    reason: Report.ReviewEvent.Reason,
    merge: Json.GitlabMergeState? = nil
  ) -> Report { .make(
    cfg: self,
    threads: .init(
      users: state.authors,
      reviews: [state.review],
      branches: Set(merge.array.map(\.targetBranch))
    ),
    ctx: Report.ReviewEvent(
      authors: state.authors.sortedNonEmpty,
      iid: state.review,
      reason: reason
    ),
    subevent: [reason.rawValue],
    merge: merge.flatMapNil(state.change?.merge)
  )}
  func reportReviewUpdated(
    state: Review.State,
    merge: Json.GitlabMergeState,
    report: Report.ReviewUpdated
  ) -> Report { .make(
    cfg: self,
    threads: .init(users: state.authors, branches: [merge.targetBranch]),
    ctx: report,
    merge: merge
  )}
//  func reportReviewRemind(
//    status: Fusion.Approval.Status,
//    slackers: Set<String>,
//    review: Json.GitlabReviewState?
//  ) -> Report { .make(
//    cfg: self,
//    threads: makeThread(review: review, status: status, infusion: nil),
//    ctx: Report.ReviewRemind(
//      authors: status.authors.sorted(),
//      slackers: slackers.sorted()
//    ),
//    review: review
//  )}
//  func reportReviewObsolete(
//    review: Json.GitlabReviewState
//  ) -> Report { .make(
//    cfg: self,
//    threads: makeThread(review: review, status: nil, infusion: nil),
//    ctx: Report.ReviewObsolete()
//  )}
//  func reportReviewCustom(
//    status: Fusion.Approval.Status,
//    event: String,
//    stdin: AnyCodable?
//  ) -> Report { .make(
//    cfg: self,
//    threads: makeThread(review: nil, status: status, infusion: nil),
//    ctx: Report.ReviewCustom(
//      authors: status.authors.sorted(),
//      stdin: stdin
//    ),
//    subevent: event.components(separatedBy: "/")
//  )}
//  func reportReviewStopped(
//    status: Fusion.Approval.Status,
//    infusion: Review.State.Infusion?,
//    reasons: [Report.ReviewStopped.Reason],
//    unknownUsers: Set<String> = [],
//    unknownTeams: Set<String> = []
//  ) -> Report { .make(
//    cfg: self,
//    threads: makeThread(review: nil, status: status, infusion: infusion),
//    ctx: Report.ReviewStopped(
//      authors: status.authors.sorted(),
//      reasons: reasons,
//      unknownUsers: unknownUsers.isEmpty.else(unknownUsers.sorted()),
//      unknownTeams: unknownTeams.isEmpty.else(unknownUsers.sorted())
//    )
//  )}
//  func reportReviewUpdated(
//    review: Review,
//    update: Review.Approval
//  ) -> Report { .make(
//    cfg: self,
//    threads: makeThread(review: nil, status: review.status, infusion: review.infusion),
//    ctx: Report.ReviewUpdated(
//      authors: review.status.authors.sorted(),
//      teams: review.status.teams.isEmpty.else(review.status.teams.sorted()),
//      watchers: review.watchers,
//      holders: update.holders.isEmpty.else(update.holders.sorted()),
//      slackers: update.slackers.isEmpty.else(update.slackers.sorted()),
//      approvers: update.approvers.isEmpty.else(update.approvers.sorted()),
//      outdaters: update.outdaters.isEmpty.else(update.outdaters.mapValues({ $0.sorted() })),
//      orphaned: update.orphaned,
//      unapprovable: update.unapprovable.isEmpty.else(update.unapprovable.sorted()),
//      state: update.state,
//      blockers: update.blockers.isEmpty.else(update.blockers)
//    )
//  )}
//  func reportReviewMergeError(
//    review: Review,
//    error: String
//  ) -> Report { .make(
//    cfg: self,
//    threads: makeThread(review: nil, status: review.status, infusion: review.infusion),
//    ctx: Report.ReviewMergeError(
//      authors: review.status.authors.sorted(),
//      error: error
//    )
//  )}
  func reportReleaseBranchCreated(
    release: Flow.Product.Release,
    hotfix: Bool
  ) -> Report { .make(
    cfg: self,
    threads: .init(branches: [release.branch.name]),
    ctx: Report.ReleaseBranchCreated(
      product: release.product,
      version: release.version.value,
      hotfix: hotfix
    )
  )}
  func reportReleaseBranchDeleted(
    release: Flow.Product.Release
  ) -> Report { .make(
    cfg: self,
    threads: .init(branches: [release.branch.name]),
    ctx: Report.ReleaseBranchDeleted(
      product: release.product,
      version: release.version.value
    )
  )}
  func reportReleaseBranchSummary(
    release: Flow.Product.Release,
    notes: Flow.ReleaseNotes
  ) -> Report { .make(
    cfg: self,
    threads: .init(branches: [release.branch.name]),
    ctx: Report.ReleaseBranchSummary(
      product: release.product,
      version: release.version.value,
      notes: notes.isEmpty.else(notes)
    )
  )}
  func reportDeployTagCreated(
    release: Flow.Product.Release,
    build: Flow.Build?,
    notes: Flow.ReleaseNotes
  ) -> Report { .make(
    cfg: self,
    threads: .init(
      tags: Set(build.flatMap(\.tag?.name).array),
      branches: [release.branch.name]
    ),
    ctx: Report.DeployTagCreated(
      product: release.product,
      version: release.version.value,
      build: build?.number.value,
      notes: notes.isEmpty.else(notes)
    )
  )}
  func reportStageTagCreated(
    stage: Flow.Product.Stage
  ) -> Report { .make(
    cfg: self,
    threads: .make(stage: stage),
    ctx: Report.StageTagCreated(
      product: stage.product,
      version: stage.version.value,
      build: stage.build.value
    )
  )}
  func reportStageTagDeleted(
    stage: Flow.Product.Stage
  ) -> Report { .make(
    cfg: self,
    threads: .make(stage: stage),
    ctx: Report.StageTagDeleted(
      product: stage.product,
      version: stage.version.value
    )
  )}
  func reportCustom(
    event: String,
    threads: Report.Threads,
    stdin: AnyCodable?,
    args: [String]
  ) -> Report { .make(
    cfg: self,
    threads: threads,
    ctx: Report.Custom(stdin: stdin),
    subevent: event.components(separatedBy: "/"),
    args: args.isEmpty.else(args)
  )}
  func reportUnexpected(
    error: Error
  ) -> Report { .make(
    cfg: self,
    threads: .init(),
    ctx: Report.Unexpected(error: String(describing: error))
  )}
  func reportAccessoryBranchCreated(
    ref: String
  ) -> Report { .make(
    cfg: self,
    threads: .init(branches: [ref]),
    ctx: Report.AccessoryBranchCreated(ref: ref)
  )}
  func reportAccessoryBranchDeleted(
    ref: String
  ) -> Report { .make(
    cfg: self,
    threads: .init(branches: [ref]),
    ctx: Report.AccessoryBranchDeleted(ref: ref)
  )}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) -> Report { .make(
    cfg: self,
    threads: .init(),
    ctx: Report.ExpiringRequisites(items: items)
  )}
}
