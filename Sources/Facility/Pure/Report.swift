import Foundation
import Facility
public protocol ReportContext: GenerateContext {}
public extension ReportContext {
  static var allowEmpty: Bool { true }
}
public struct Report {
  public var threads: Threads
  public var info: GenerateInfo
  public var merge: Json.GitlabMergeState?
  fileprivate static func make<Context: ReportContext>(
    cfg: Configuration,
    threads: Threads,
    ctx: Context,
    merge: Json.GitlabMergeState?,
    subevent: [String] = [],
    args: [String]? = nil
  ) -> Self { .init(
    threads: threads,
    info: Generate.Info.make(cfg: cfg, context: ctx, subevent: subevent, args: args),
    merge: merge
  )}
  #warning("TBD eliminate shared state")
  public class Bag {
    public static let shared = Bag()
    public fileprivate(set) var reports: [Report] = []
  }
  public struct Threads {
    public var tags: Set<String> = []
    public var users: Set<String> = []
    public var issues: Set<String> = []
    public var reviews: Set<String> = []
    public var branches: Set<String> = []
    public static func make(
      tags: Set<String> = [],
      users: Set<String> = [],
      issues: Set<String> = [],
      reviews: Set<UInt> = [],
      branches: Set<String> = []
    ) -> Self { .init(
      tags: tags,
      users: users,
      issues: issues,
      reviews: Set(reviews.map({ "\($0)" })),
      branches: branches
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
    public var iid: UInt
    public var authors: [String]?
    public var teams: [String]?
    public var approvers: [Review.Approver]? = nil
    public var problems: Review.Problems? = nil
    public var reason: Reason
    public enum Reason: String, Encodable {
      case block
      case stuck
      case amend
      case ready
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
    public var authors: [String]?
    public var error: String
  }
  public struct ReviewUpdated: ReportContext {
    public var authors: [String]?
    public var teams: [String]?
    public var watchers: [String]?
    public var approvers: [Review.Approver]? = nil
    public var problems: Review.Problems? = nil
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
    public var authors: [String]?
    public var product: String?
    public var version: String?
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
  var defaultUsers: Set<String> {
    guard let gitlab = try? gitlab.get() else { return [] }
    var result = Set([gitlab.job.user.username])
    if let parent = try? gitlab.parent.get() { result.insert(parent.user.username) }
    return result
  }
  func report(
    notify: Report.Notify,
    user: String? = nil,
    merge: Json.GitlabMergeState? = nil
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(
      users: user.map({ Set([$0]) }).get(defaultUsers),
      reviews: Set(merge.array.map(\.iid))
    ),
    ctx: notify,
    merge: merge,
    subevent: [notify.rawValue]
  ))}
  func reportReviewList(
    user: String,
    reviews: [UInt: Report.ReviewApprove]
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(users: [user]),
    ctx: Report.ReviewList(reviews: reviews),
    merge: nil
  ))}
  func reportReviewApprove(
    user: String,
    merge: Json.GitlabMergeState,
    approve: Report.ReviewApprove
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(users: [user], reviews: [merge.iid]),
    ctx: approve,
    merge: merge
  ))}
  func reportReviewEvent(
    state: Review.State,
    update: Report.ReviewUpdated?,
    reason: Report.ReviewEvent.Reason,
    merge: Json.GitlabMergeState? = nil
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(
      users: state.authors,
      reviews: [state.review],
      branches: Set(merge.array.map(\.targetBranch))
    ),
    ctx: Report.ReviewEvent(
      iid: state.review,
      authors: state.authors.sortedNonEmpty,
      teams: state.teams.sortedNonEmpty,
      approvers: update?.approvers,
      problems: update?.problems,
      reason: reason
    ),
    merge: merge.flatMapNil(state.change?.merge),
    subevent: [reason.rawValue]
  ))}
  func reportReviewUpdated(
    state: Review.State,
    merge: Json.GitlabMergeState,
    report: Report.ReviewUpdated
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(reviews: [merge.iid]),
    ctx: report,
    merge: merge
  ))}
  func reportReviewMergeError(
    state: Review.State,
    merge: Json.GitlabMergeState,
    error: String
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(users: state.authors, reviews: [merge.iid]),
    ctx: Report.ReviewMergeError(
      authors: state.authors.sortedNonEmpty,
      error: error
    ),
    merge: merge
  ))}
  func reportReleaseBranchCreated(
    release: Flow.Product.Release,
    hotfix: Bool
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [release.branch.name]),
    ctx: Report.ReleaseBranchCreated(
      product: release.product,
      version: release.version.value,
      hotfix: hotfix
    ),
    merge: nil
  ))}
  func reportReleaseBranchDeleted(
    release: Flow.Product.Release
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [release.branch.name]),
    ctx: Report.ReleaseBranchDeleted(
      product: release.product,
      version: release.version.value
    ),
    merge: nil
  ))}
  func reportReleaseBranchSummary(
    release: Flow.Product.Release,
    notes: Flow.ReleaseNotes
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [release.branch.name]),
    ctx: Report.ReleaseBranchSummary(
      product: release.product,
      version: release.version.value,
      notes: notes.isEmpty.else(notes)
    ),
    merge: nil
  ))}
  func reportDeployTagCreated(
    release: Flow.Product.Release,
    build: Flow.Build?,
    notes: Flow.ReleaseNotes
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(
      tags: Set(build.flatMap(\.tag?.name).array),
      branches: [release.branch.name]
    ),
    ctx: Report.DeployTagCreated(
      product: release.product,
      version: release.version.value,
      build: build?.number.value,
      notes: notes.isEmpty.else(notes)
    ),
    merge: nil
  ))}
  func reportStageTagCreated(
    stage: Flow.Product.Stage
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(tags: [stage.tag.name], branches: Set(stage.branch.array.map(\.name))),
    ctx: Report.StageTagCreated(
      product: stage.product,
      version: stage.version.value,
      build: stage.build.value
    ),
    merge: nil
  ))}
  func reportStageTagDeleted(
    stage: Flow.Product.Stage
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(tags: [stage.tag.name], branches: Set(stage.branch.array.map(\.name))),
    ctx: Report.StageTagDeleted(
      product: stage.product,
      version: stage.version.value
    ),
    merge: nil
  ))}
  func reportCustom(
    event: String,
    threads: Report.Threads,
    stdin: AnyCodable?,
    args: [String],
    authors: [String]? = nil,
    product: String? = nil,
    version: String? = nil
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: threads,
    ctx: Report.Custom(
      authors: authors,
      product: product,
      version: version,
      stdin: stdin
    ),
    merge: nil,
    subevent: event.components(separatedBy: "/"),
    args: args.isEmpty.else(args)
  ))}
  func reportUnexpected(
    error: Error
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(users: defaultUsers),
    ctx: Report.Unexpected(error: String(describing: error)),
    merge: nil
  ))}
  func reportAccessoryBranchCreated(
    ref: String
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [ref]),
    ctx: Report.AccessoryBranchCreated(ref: ref),
    merge: nil
  ))}
  func reportAccessoryBranchDeleted(
    ref: String
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [ref]),
    ctx: Report.AccessoryBranchDeleted(ref: ref),
    merge: nil
  ))}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(),
    ctx: Report.ExpiringRequisites(items: items),
    merge: nil
  ))}
}
