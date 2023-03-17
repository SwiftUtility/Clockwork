import Foundation
import Facility
public struct Report {
  public var threads: Threads
  public var info: GenerateInfo
  fileprivate static func make<Context: GenerateContext>(
    threads: Threads,
    ctx: Context,
    subevent: [String] = [],
    stdin: AnyCodable? = nil,
    args: [String]? = nil
  ) -> Self { .init(
    threads: threads,
    info: Generate.Info.make(context: ctx, subevent: subevent, stdin: stdin, args: args)
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
  public struct FusionFail: GenerateContext {
    public var source: String
    public var target: String
    public var fork: String
    public var reason: Reason
    public enum Reason: String, Encodable {
      case propogate
      case duplicate
    }
  }
  public struct ReviewFail: GenerateContext {
    public var merge: Json.GitlabMerge
    public var review: Review.Info
    public var reason: Reason
    public enum Reason: String, Encodable {
      case pipelineOutdated
      case reviewQueued
      case rebaseBlocked
      case patchFailed
    }
  }
  public struct ReviewList: GenerateContext {
    public var user: String
    public var reviews: [ReviewApprove]
    public enum Reason: String, Encodable {
      case full
      case empty
    }
  }
  public struct ReviewWatch: GenerateContext {
    public var user: String
    public var merge: Json.GitlabMerge
    public var review: Review.Info
  }
  public struct ReviewApprove: GenerateContext {
    public var user: String
    public var diff: String?
    public var merge: Json.GitlabMerge
    public var review: Review.Info
    public var reason: Reason
    public static func make(
      merge: Json.GitlabMerge,
      state: Review.State,
      user: String
    ) -> Self { .init(
      user: user,
      diff: state.approves[user]?.diff,
      merge: merge,
      review: .init(state: state),
      reason: .remind
    )}
    public enum Reason: String, Encodable {
      case remind
      case change
      case create
    }
  }
  public struct ReviewQueue: GenerateContext {
    public var review: Review.Info
    public var reason: Reason
    public enum Reason: String, Encodable {
      case foremost
      case enqueued
      case dequeued
    }
  }
  public struct ReviewEvent: GenerateContext {
    public var merge: Json.GitlabMerge
    public var review: Review.Info
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
  public struct ReviewMergeError: GenerateContext {
    public var merge: Json.GitlabMerge
    public var review: Review.Info
    public var error: String
  }
  public struct ReviewUpdated: GenerateContext {
    public var merge: Json.GitlabMerge
    public var review: Review.Info
  }
  public struct ReleaseBranchCreated: GenerateContext {
    public var commit: String
    public var branch: String
    public var product: String
    public var version: String
    public var kind: Flow.Release.Kind
  }
  public struct ReleaseBranchDeleted: GenerateContext {
    public var branch: String
    public var product: String
    public var version: String
    public var kind: Flow.Release.Kind
  }
  public struct ReleaseBranchSummary: GenerateContext {
    public var commit: String
    public var branch: String
    public var product: String
    public var version: String
    public var notes: Flow.ReleaseNotes?
  }
  public struct DeployTagCreated: GenerateContext {
    public var commit: String
    public var branch: String
    public var tag: String
    public var product: String
    public var version: String
    public var build: String
    public var notes: Flow.ReleaseNotes?
  }
  public struct DeployTagDeleted: GenerateContext {
    public var tag: String
    public var product: String
    public var version: String
    public var build: String
  }
  public struct StageTagCreated: GenerateContext {
    public var commit: String
    public var tag: String
    public var product: String
    public var version: String
    public var build: String
  }
  public struct StageTagDeleted: GenerateContext {
    public var tag: String
    public var product: String
    public var version: String
    public var build: String
  }
  public struct AccessoryBranchCreated: GenerateContext {
    public var commit: String
    public var branch: String
  }
  public struct AccessoryBranchDeleted: GenerateContext {
    public var branch: String
  }
  public struct Custom: GenerateContext {
    public var merge: Json.GitlabMerge?
    public var review: Review.Info?
    public var product: String?
    public var version: String?
  }
  public struct Unexpected: GenerateContext {
    public var merge: Json.GitlabMerge?
    public var error: String
  }
  public struct ExpiringRequisites: GenerateContext {
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
    threads: .make(users: defaultUsers),
    ctx: Report.FusionFail(source: source, target: target, fork: fork, reason: reason),
    subevent: [reason.rawValue]
  ))}
  func reportReviewFail(
    merge: Json.GitlabMerge,
    state: Review.State,
    reason: Report.ReviewFail.Reason
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(users: defaultUsers.union(state.authors), reviews: [merge.iid]),
    ctx: Report.ReviewFail(merge: merge, review: .init(state: state), reason: reason),
    subevent: [reason.rawValue]
  ))}
  func reportReviewWatch(
    user: String,
    merge: Json.GitlabMerge,
    state: Review.State
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(users: [user]),
    ctx: Report.ReviewWatch(user: user, merge: merge, review: .init(state: state))
  ))}
  func reportReviewList(
    user: String,
    reviews: [Report.ReviewApprove]
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(users: [user]),
    ctx: Report.ReviewList(user: user, reviews: reviews),
    subevent: [reviews.isEmpty.then(Report.ReviewList.Reason.empty).get(.full).rawValue]
  ))}
  func reportReviewApprove(
    user: String,
    merge: Json.GitlabMerge,
    state: Review.State,
    reason: Report.ReviewApprove.Reason
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(users: [user], reviews: [state.review]),
    ctx: Report.ReviewApprove.init(
      user: user,
      diff: state.approves[user]?.commit.value,
      merge: merge,
      review: .init(state: state),
      reason: reason
    ),
    subevent: [reason.rawValue]
  ))}
  func reportReviewQueue(
    state: Review.State,
    reason: Report.ReviewQueue.Reason
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(
      users: state.authors,
      reviews: [state.review],
      branches: [state.target.name]
    ),
    ctx: Report.ReviewQueue(review: .init(state: state), reason: reason),
    subevent: [reason.rawValue]
  ))}
  func reportReviewEvent(
    state: Review.State,
    merge: Json.GitlabMerge,
    reason: Report.ReviewEvent.Reason
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(
      users: state.authors,
      issues: issues(branch: merge.sourceBranch),
      reviews: [state.review],
      branches: [state.target.name]
    ),
    ctx: Report.ReviewEvent(merge: merge, review: .init(state: state), reason: reason),
    subevent: [reason.rawValue]
  ))}
  func reportReviewUpdated(
    state: Review.State,
    merge: Json.GitlabMerge
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(reviews: [state.review]),
    ctx: Report.ReviewUpdated(merge: merge, review: .init(state: state))
  ))}
  func reportReviewMergeError(
    state: Review.State,
    merge: Json.GitlabMerge,
    error: String
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(users: state.authors, reviews: [merge.iid]),
    ctx: Report.ReviewMergeError(merge: merge, review: .init(state: state), error: error)
  ))}
  func reportReleaseBranchCreated(
    release: Flow.Release,
    kind: Flow.Release.Kind
  ) { Report.Bag.shared.reports.append(.make(
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
  func reportStageTagCreated(
    commit: Git.Sha,
    stage: Flow.Stage
  ) { Report.Bag.shared.reports.append(.make(
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
  func reportCustom(
    event: String,
    threads: Report.Threads,
    stdin: AnyCodable?,
    args: [String],
    state: Review.State? = nil,
    merge: Json.GitlabMerge? = nil,
    product: String? = nil,
    version: String? = nil
  ) { Report.Bag.shared.reports.append(.make(
    threads: threads,
    ctx: Report.Custom(
      merge: merge,
      review: state.map(Review.Info.init(state:)),
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
    threads: .make(branches: [accessory.branch.name]),
    ctx: Report.AccessoryBranchCreated(commit: commit.value, branch: accessory.branch.name)
  ))}
  func reportAccessoryBranchDeleted(
    accessory: Flow.Accessory
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(branches: [accessory.branch.name]),
    ctx: Report.AccessoryBranchDeleted(branch: accessory.branch.name)
  ))}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) { Report.Bag.shared.reports.append(.make(
    threads: .make(),
    ctx: Report.ExpiringRequisites(items: items)
  ))}
}
public extension Report {
  static func deployTagDeleted(
    parent: Json.GitlabJob,
    deploy: Flow.Deploy,
    release: Flow.Release?
  ) -> Self { .make(
    threads: .make(
      tags: [deploy.tag.name],
      users: [parent.user.username],
      branches: Set(release.map(\.branch.name).array)
    ),
    ctx: Report.DeployTagDeleted(
      tag: deploy.tag.name,
      product: deploy.product,
      version: deploy.version.value,
      build: deploy.build.value
    ),
    subevent: [deploy.product]
  )}
  static func stageTagDeleted(
    parent: Json.GitlabJob,
    stage: Flow.Stage
  ) -> Self { .make(
    threads: .make(
      tags: [stage.tag.name],
      users: [parent.user.username],
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
  )}
}
