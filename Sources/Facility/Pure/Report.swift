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
    public var jiraIssues: Set<String>
    public var gitlabTags: Set<String>
    public var gitlabUsers: Set<String>
    public var gitlabBranches: Set<String>
    public static func make(
      jiraIssues: Set<String> = [],
      gitlabTags: Set<String> = [],
      gitlabUsers: Set<String> = [],
      gitlabBranches: Set<String> = []
    ) -> Self { .init(
      jiraIssues: jiraIssues,
      gitlabTags: gitlabTags,
      gitlabUsers: gitlabUsers,
      gitlabBranches: gitlabBranches
    )}
//    public static func make(
//      build: Flow.Build
//    ) -> Self { .init(
//      jiraIssues: [],
//      gitlabTags: [],
//      gitlabUsers: [],
//      gitlabReviews: Set(build.review.array),
//      gitlabBranches: Set(build.branch.array)
//    )}
    public static func make(
      stage: Flow.Product.Stage
    ) -> Self { .init(
      jiraIssues: [],
      gitlabTags: [stage.tag.name],
      gitlabUsers: [],
      gitlabBranches: Set(stage.branch.array.map(\.name))
    )}
  }
  public struct ReviewCreated: ReportContext {
    public var authors: [String]
  }
  public struct ReviewMergeConflicts: ReportContext {
    public var authors: [String]
  }
  public struct ReviewClosed: ReportContext {
    public var authors: [String]
  }
  public struct ReviewStopped: ReportContext {
    public var authors: [String]
    public var reasons: [Reason]
    public var unknownUsers: [String]?
    public var unknownTeams: [String]?
    public enum Reason: String, Encodable {
      case botSquash
      case notBotMerge
      case extraCommits
      case forkInTarget
      case forkNotInSource
      case forkNotInOriginal
      case forkParentNotInTarget
      case forkTargetMismatch
      case noSourceRule
      case sourceFormat
      case multipleRules
      case targetNotDefault
      case targetNotProtected
      case sourceIsProtected
      case originalNotProtected
      case sanity
      case unknownTeams
      case unknownUsers
      public var logMessage: LogMessage {
        switch self {
        case .botSquash: return .init(message: "Author of proposition is bot")
        case .notBotMerge: return .init(message: "Author of merging is not bot")
        case .extraCommits: return .init(message: "Source branch contains non protected commits")
        case .forkInTarget: return .init(message: "Fork commit is already in target branch")
        case .forkNotInSource: return .init(message: "Fork commit is not in source branch")
        case .forkNotInOriginal: return .init(message: "Fork commit is not in fork subject branch")
        case .forkParentNotInTarget: return .init(message: "Fork parent is not in target branch")
        case .forkTargetMismatch: return .init(message: "Fork target branch changed")
        case .noSourceRule: return .init(message: "No rule for source branch")
        case .sourceFormat: return .init(message: "Bad formated merge branch")
        case .multipleRules: return .init(message: "Multiple rules for source branch")
        case .targetNotDefault: return .init(message: "Target branch is not default")
        case .targetNotProtected: return .init(message: "Target branch is not protected")
        case .sanity: return .init(message: "Sanity group does not track approval configuration")
        case .sourceIsProtected: return .init(message: "Source branch is protected")
        case .originalNotProtected: return .init(message: "Fork subject branch is not protected")
        case .unknownTeams: return .init(message: "Found not configured teams")
        case .unknownUsers: return .init(message: "Found not registered users")
        }
      }
    }
  }
//  public struct ReviewUpdated: ReportContext {
//    public var authors: [String]
//    public var teams: [String]?
//    public var watchers: [String]?
//    public var holders: [String]?
//    public var slackers: [String]?
//    public var approvers: [String]?
//    public var outdaters: [String: [String]]?
//    public var orphaned: Bool
//    public var unapprovable: [String]?
//    public var state: Review.Approval.State
//    public var subevent: [String] { [state.rawValue] }
//    public var blockers: [Blocker]?
//    public enum Blocker: String, Encodable {
//      case badTitle
//      case draft
//      case discussions
//      case squashStatus
//      case workInProgress
//      case taskMismatch
//    }
//  }
//  public struct ReviewMerged: ReportContext {
//    public var authors: [String]
//    public var teams: [String]?
//    public var watchers: [String]?
//    public var approvers: [String]?
//    public var state: Review.Approval.State
//    public var subevent: [String] { [state.rawValue] }
//  }
  public struct ReviewMergeError: ReportContext {
    public var authors: [String]
    public var error: String
  }
  public struct ReviewRemind: ReportContext {
    public var authors: [String]
    public var slackers: [String]
  }
  public struct ReviewObsolete: ReportContext {
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
  func makeThread(
    merge: Json.GitlabMergeState?,
    state: Review.State?,
    fusion: Review.Fusion?
  ) -> Report.Threads {
    var result = Report.Threads.make()
    #warning("tbd")
//    let gitlab = try? gitlab.get()
//    let review = review.flatMapNil(try? gitlab?.review.get())
//    result.gitlabBranches.formUnion(review.map(\.targetBranch).array)
//    result.gitlabUsers = status
//      .map(\.authors)
//      .get(Set(review.map(\.author.username).array))
//      .intersection(gitlab.map(\.activeUsers).get([]))
//    if let infusion = infusion, let task = infusion.squash?.proposition.task {
//      result.jiraIssues.formUnion(infusion.source.name.find(matches: task))
//    }
    return result
  }
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
  func reportReviewClosed(
    state: Review.State,
    merge: Json.GitlabMergeState
  ) -> Report { .make(
    cfg: self,
    threads: makeThread(merge: merge, state: state, fusion: nil),
    ctx: Report.ReviewClosed(authors: state.authors.sorted()),
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
//  func reportReviewMerged(
//    review: Review
//  ) -> Report { .make(
//    cfg: self,
//    threads: makeThread(review: nil, status: review.status, infusion: review.infusion),
//    ctx: Report.ReviewMerged(
//      authors: review.status.authors.sorted(),
//      teams: review.status.teams.isEmpty.else(review.status.teams.sorted()),
//      watchers: review.watchers,
//      approvers: review.accepters,
//      state: review.status.emergent
//        .map({_ in .emergent})
//        .get(.approved)
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
    threads: .make(gitlabBranches: [release.branch.name]),
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
    threads: .make(gitlabBranches: [release.branch.name]),
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
    threads: .make(gitlabBranches: [release.branch.name]),
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
    threads: .make(
      gitlabTags: Set(build.flatMap(\.tag?.name).array),
      gitlabBranches: [release.branch.name]
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
    threads: .make(),
    ctx: Report.Unexpected(error: String(describing: error))
  )}
  func reportAccessoryBranchCreated(
    ref: String
  ) -> Report { .make(
    cfg: self,
    threads: .make(gitlabBranches: [ref]),
    ctx: Report.AccessoryBranchCreated(ref: ref)
  )}
  func reportAccessoryBranchDeleted(
    ref: String
  ) -> Report { .make(
    cfg: self,
    threads: .make(gitlabBranches: [ref]),
    ctx: Report.AccessoryBranchDeleted(ref: ref)
  )}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) -> Report { .make(
    cfg: self,
    threads: .make(),
    ctx: Report.ExpiringRequisites(items: items)
  )}
}
