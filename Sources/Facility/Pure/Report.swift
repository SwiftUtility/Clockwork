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
    subevent: [String] = [],
    stdin: AnyCodable? = nil,
    args: [String]? = nil
  ) -> Self { .init(
    threads: threads,
    info: Generate.Info.make(cfg: cfg, context: ctx, subevent: subevent, stdin: stdin, args: args)
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
  public struct FusionFail: ReportContext {
    public var source: String
    public var target: String
    public var fork: String
    public var reason: Reason
    public enum Reason: String, Encodable {
      case propogate
      case duplicate
    }
  }
  public struct ReviewFail: ReportContext {
    public var merge: Json.GitlabMergeState
    public var reason: Reason
    public enum Reason: String, Encodable {
      case pipelineOutdated
      case reviewQueued
      case rebaseBlocked
      case patchFailed
    }
  }
  public struct ReviewList: ReportContext {
    public var reviews: [ReviewApprove]
    public enum Reason: String, Encodable {
      case full
      case empty
    }
  }
  public struct ReviewApprove: ReportContext {
    public var iid: UInt
    public var authors: [String]?
    public var teams: [String]?
    public var diff: String?
    public var reason: Reason
    public static func make(state: Review.State, user: String) -> Self { .init(
      iid: state.review,
      authors: state.authors.sortedNonEmpty,
      teams: state.teams.sortedNonEmpty,
      diff: state.approves[user]?.diff,
      reason: .remind
    )}
    public enum Reason: String, Encodable {
      case remind
      case change
      case create
    }
  }
  public struct ReviewQueue: ReportContext {
    public var iid: UInt
    public var authors: [String]?
    public var teams: [String]?
    public var reason: Reason
    public enum Reason: String, Encodable {
      case foremost
      case enqueued
      case dequeued
    }
  }
  public struct ReviewEvent: ReportContext {
    public var merge: Json.GitlabMergeState
    public var authors: [String]?
    public var teams: [String]?
    public var reason: Reason
    public enum Reason: String, Encodable {
      case block
      case stuck
      case amend
      case ready
      case closed
      case merged
      case created
      case emergent
      case tranquil
      case conflicts
    }
  }
  public struct ReviewMergeError: ReportContext {
    public var merge: Json.GitlabMergeState
    public var authors: [String]?
    public var teams: [String]?
    public var error: String
  }
  public struct ReviewUpdated: ReportContext {
    public var merge: Json.GitlabMergeState
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
    public var commit: String
    public var branch: String
    public var product: String
    public var version: String
    public var kind: Flow.Release.Kind
  }
  public struct ReleaseBranchDeleted: ReportContext {
    public var branch: String
    public var product: String
    public var version: String
    public var kind: Flow.Release.Kind
  }
  public struct ReleaseBranchSummary: ReportContext {
    public var commit: String
    public var branch: String
    public var product: String
    public var version: String
    public var notes: Flow.ReleaseNotes?
  }
  public struct DeployTagCreated: ReportContext {
    public var commit: String
    public var branch: String
    public var tag: String
    public var product: String
    public var version: String
    public var build: String
    public var notes: Flow.ReleaseNotes?
  }
  public struct DeployTagDeleted: ReportContext {
    public var tag: String
    public var product: String
    public var version: String
    public var build: String
  }
  public struct StageTagCreated: ReportContext {
    public var commit: String
    public var tag: String
    public var product: String
    public var version: String
    public var build: String
  }
  public struct StageTagDeleted: ReportContext {
    public var tag: String
    public var product: String
    public var version: String
    public var build: String
  }
  public struct AccessoryBranchCreated: ReportContext {
    public var commit: String
    public var branch: String
  }
  public struct AccessoryBranchDeleted: ReportContext {
    public var branch: String
  }
  public struct Custom: ReportContext {
    public var authors: [String]?
    public var merge: Json.GitlabMergeState?
    public var product: String?
    public var version: String?
  }
  public struct Unexpected: ReportContext {
    public var merge: Json.GitlabMergeState?
    public var error: String
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
  func issues(branch: String) -> Set<String> {
    guard let jira = try? jira.get() else { return [] }
    return jira.issue
      .matches(
        in: branch,
        options: .withoutAnchoringBounds,
        range: .init(branch.startIndex..<branch.endIndex, in: branch)
      )
      .compactMap({ Range($0.range, in: branch) })
      .reduce(into: Set(), { $0.insert(String(branch[$1])) })
  }
  func reportFusionFail(
    source: String,
    target: String,
    fork: String,
    reason: Report.FusionFail.Reason
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(users: defaultUsers),
    ctx: Report.FusionFail(source: source, target: target, fork: fork, reason: reason),
    subevent: [reason.rawValue]
  ))}
  func reportReviewFail(
    merge: Json.GitlabMergeState,
    state: Review.State?,
    reason: Report.ReviewFail.Reason
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(users: defaultUsers.union(state.map(\.authors).get([])), reviews: [merge.iid]),
    ctx: Report.ReviewFail(merge: merge, reason: reason),
    subevent: [reason.rawValue]
  ))}
  func reportReviewList(
    user: String,
    reviews: [Report.ReviewApprove]
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(users: [user]),
    ctx: Report.ReviewList(reviews: reviews),
    subevent: [reviews.isEmpty.then(Report.ReviewList.Reason.empty).get(.full).rawValue]
  ))}
  func reportReviewApprove(
    user: String,
    state: Review.State,
    reason: Report.ReviewApprove.Reason
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(users: [user], reviews: [state.review]),
    ctx: Report.ReviewApprove.init(
      iid: state.review,
      authors: state.authors.sortedNonEmpty,
      teams: state.teams.sortedNonEmpty,
      diff: state.approves[user]?.commit.value,
      reason: reason
    ),
    subevent: [reason.rawValue]
  ))}
  func reportReviewQueue(
    state: Review.State,
    reason: Report.ReviewQueue.Reason
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(
      users: state.authors,
      reviews: [state.review],
      branches: [state.target.name]
    ),
    ctx: Report.ReviewQueue(
      iid: state.review,
      authors: state.authors.sortedNonEmpty,
      teams: state.teams.sortedNonEmpty,
      reason: reason
    ),
    subevent: [reason.rawValue]
  ))}
  func reportReviewEvent(
    state: Review.State,
    merge: Json.GitlabMergeState,
    reason: Report.ReviewEvent.Reason
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(
      users: state.authors,
      issues: issues(branch: merge.sourceBranch),
      reviews: [state.review],
      branches: [state.target.name]
    ),
    ctx: Report.ReviewEvent(
      merge: merge,
      authors: state.authors.sortedNonEmpty,
      teams: state.teams.sortedNonEmpty,
      reason: reason
    ),
    subevent: [reason.rawValue]
  ))}
  func reportReviewUpdated(
    state: Review.State,
    report: Report.ReviewUpdated
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(reviews: [state.review]),
    ctx: report
  ))}
  func reportReviewMergeError(
    state: Review.State,
    merge: Json.GitlabMergeState,
    error: String
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(users: state.authors, reviews: [merge.iid]),
    ctx: Report.ReviewMergeError(
      merge: merge,
      authors: state.authors.sortedNonEmpty,
      teams: state.teams.sortedNonEmpty,
      error: error
    )
  ))}
  func reportReleaseBranchCreated(
    release: Flow.Release,
    kind: Flow.Release.Kind
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [release.branch.name]),
    ctx: Report.ReleaseBranchCreated(
      commit: release.start.value,
      branch: release.branch.name,
      product: release.product,
      version: release.version.value,
      kind: kind
    ),
    subevent: [release.product, kind.rawValue]
  ))}
  func reportReleaseBranchDeleted(
    release: Flow.Release,
    kind: Flow.Release.Kind
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [release.branch.name]),
    ctx: Report.ReleaseBranchDeleted(
      branch: release.branch.name,
      product: release.product,
      version: release.version.value,
      kind: kind
    ),
    subevent: [release.product, kind.rawValue]
  ))}
  func reportReleaseBranchSummary(
    release: Flow.Release,
    notes: Flow.ReleaseNotes
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [release.branch.name]),
    ctx: Report.ReleaseBranchSummary(
      commit: release.start.value,
      branch: release.branch.name,
      product: release.product,
      version: release.version.value,
      notes: notes.isEmpty.else(notes)
    ),
    subevent: [release.product]
  ))}
  func reportDeployTagCreated(
    commit: Git.Sha,
    release: Flow.Release,
    deploy: Flow.Deploy,
    notes: Flow.ReleaseNotes
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(tags: [deploy.tag.name], users: defaultUsers, branches: [release.branch.name]),
    ctx: Report.DeployTagCreated(
      commit: commit.value,
      branch: release.branch.name,
      tag: deploy.tag.name,
      product: deploy.product,
      version: deploy.version.value,
      build: deploy.build.value,
      notes: notes.isEmpty.else(notes)
    ),
    subevent: [deploy.product]
  ))}
  func reportDeployTagDeleted(
    deploy: Flow.Deploy,
    release: Flow.Release?
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(
      tags: [deploy.tag.name],
      users: defaultUsers,
      branches: Set(release.map(\.branch.name).array)
    ),
    ctx: Report.DeployTagDeleted(
      tag: deploy.tag.name,
      product: deploy.product,
      version: deploy.version.value,
      build: deploy.build.value
    ),
    subevent: [deploy.product]
  ))}
  func reportStageTagCreated(
    commit: Git.Sha,
    stage: Flow.Stage
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(
      tags: [stage.tag.name],
      users: defaultUsers,
      reviews: Set(stage.review.array),
      branches: [stage.branch.name]
    ),
    ctx: Report.StageTagCreated(
      commit: commit.value,
      tag: stage.tag.name,
      product: stage.product,
      version: stage.version.value,
      build: stage.build.value
    ),
    subevent: [stage.product]
  ))}
  func reportStageTagDeleted(
    stage: Flow.Stage
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(
      tags: [stage.tag.name],
      users: defaultUsers,
      reviews: Set(stage.review.array),
      branches: [stage.branch.name]
    ),
    ctx: Report.StageTagDeleted(
      tag: stage.tag.name,
      product: stage.product,
      version: stage.version.value,
      build: stage.build.value
    ),
    subevent: [stage.product]
  ))}
  func reportCustom(
    event: String,
    threads: Report.Threads,
    stdin: AnyCodable?,
    args: [String],
    state: Review.State? = nil,
    merge: Json.GitlabMergeState? = nil,
    product: String? = nil,
    version: String? = nil
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: threads,
    ctx: Report.Custom(
      authors: state?.authors.sortedNonEmpty,
      merge: merge,
      product: product,
      version: version
    ),
    subevent: event.components(separatedBy: "/"),
    stdin: stdin,
    args: args.isEmpty.else(args)
  ))}
  func reportUnexpected(
    error: Error
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(
      users: defaultUsers,
      reviews: Set((try? gitlab.flatMap(\.parent).flatMap(\.review).get()).array)
    ),
    ctx: Report.Unexpected(
      merge: try? gitlab.flatMap(\.merge).get(),
      error: String(describing: error)
    )
  ))}
  func reportAccessoryBranchCreated(
    commit: Git.Sha,
    accessory: Flow.Accessory
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [accessory.branch.name]),
    ctx: Report.AccessoryBranchCreated(commit: commit.value, branch: accessory.branch.name)
  ))}
  func reportAccessoryBranchDeleted(
    accessory: Flow.Accessory
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(branches: [accessory.branch.name]),
    ctx: Report.AccessoryBranchDeleted(branch: accessory.branch.name)
  ))}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) { Report.Bag.shared.reports.append(.make(
    cfg: self,
    threads: .make(),
    ctx: Report.ExpiringRequisites(items: items)
  ))}
}
