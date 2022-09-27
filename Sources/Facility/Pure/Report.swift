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
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var author: String
    public var coauthors: [String: String]?
  }
  public struct ReviewMergeConflicts: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var author: String
    public var coauthors: [String: String]?
  }
  public struct ReviewClosed: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var author: String
    public var coauthors: [String: String]?
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
    }
  }
  public struct ReviewBlocked: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var thread: Configuration.Thread
    public var review: Json.GitlabReviewState
    public var users: [String: Fusion.Approval.Approver]
    public var author: String
    public var coauthors: [String: String]?
    public var reasons: [Reason]
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
    }
  }



  public struct Custom: GenerationContext {
    public var event: String = Self.event
    public var subevent: String
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var stdin: [String]?
  }
  public struct ReviewCustom: GenerationContext {
    public var event: String = Self.event
    public var subevent: String
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var stdin: [String]?
  }
  public struct Unexpected: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var error: String
  }
  public struct UnownedCode: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var files: [String]
  }
  public struct FileTaboos: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var issues: [FileTaboo.Issue]
  }
  public struct ReviewObsolete: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var files: [String]?
  }
  public struct ForbiddenCommits: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var commits: [String]?
  }
  public struct ConflictMarkers: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var markers: [String]
  }
  public struct ReviewMerged: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
  }
  public struct ReviewMergeError: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var users: Set<String>
    public var error: String
  }
//  public struct EmergencyAwardApproval: GenerationContext {
//    public var event: String = Self.event
//    public var env: [String: String]
//    public var ctx: AnyCodable?
//    public var info: GitlabCi.Info?
//    public var review: Json.GitlabReviewState
//    public var users: Set<String>
//    public var cheaters: Set<String>
//  }
//  public struct AwardApprovalReady: GenerationContext {
//    public var event: String = Self.event
//    public var env: [String: String]
//    public var ctx: AnyCodable?
//    public var info: GitlabCi.Info?
//    public var review: Json.GitlabReviewState
//    public var users: Set<String>
//  }
//  public struct NewAwardApproval: GenerationContext {
//    public var event: String = Self.event
//    public var env: [String: String]
//    public var ctx: AnyCodable?
//    public var info: GitlabCi.Info?
//    public var review: Json.GitlabReviewState
//    public var users: Set<String>
//    public var group: AwardApproval.Group.Report
//    public var subevent: String { group.name }
//  }
//  public struct WaitAwardApproval: GenerationContext {
//    public var event: String = Self.event
//    public var env: [String: String]
//    public var ctx: AnyCodable?
//    public var info: GitlabCi.Info?
//    public var review: Json.GitlabReviewState
//    public var users: Set<String>
//    public var group: AwardApproval.Group.Report
//    public var subevent: String { group.name }
//  }
//  public struct NewAwardApprovals: GenerationContext {
//    public var event: String = Self.event
//    public var env: [String: String]
//    public var ctx: AnyCodable?
//    public var info: GitlabCi.Info?
//    public var review: Json.GitlabReviewState
//    public var users: Set<String>
//    public var groups: [AwardApproval.Group.Report]
//  }
//  public struct WaitAwardApprovals: GenerationContext {
//    public var event: String = Self.event
//    public var env: [String: String]
//    public var ctx: AnyCodable?
//    public var info: GitlabCi.Info?
//    public var review: Json.GitlabReviewState
//    public var users: Set<String>
//    public var groups: [AwardApproval.Group.Report]
//  }
//  public struct AwardApprovalHolders: GenerationContext {
//    public var event: String = Self.event
//    public var env: [String: String]
//    public var ctx: AnyCodable?
//    public var info: GitlabCi.Info?
//    public var review: Json.GitlabReviewState
//    public var users: Set<String>
//    public var holders: Set<String>
//  }
  public struct ReleaseBranchCreated: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
    public var product: String
    public var version: String
    public var subevent: String { product }
  }
  public struct HotfixBranchCreated: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
    public var product: String
    public var version: String
    public var subevent: String { product }
  }
  public struct DeployTagCreated: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
    public var product: String
    public var deploy: Production.Build.Deploy
    public var uniq: [Commit]?
    public var heir: [Commit]?
    public var lack: [Commit]?
    public var subevent: String { product }
    public struct Commit: Encodable {
      public var sha: String
      public var msg: String
      public static func make(sha: String, msg: String) -> Self { .init(sha: sha, msg: msg) }
    }
  }
  public struct VersionBumped: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
    public var subevent: String { product }
  }
  public struct AccessoryBranchCreated: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
  }
  public struct ExpiringRequisites: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
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
  func reportReviewCreated(
    fusion: Fusion,
    review: Json.GitlabReviewState,
    users: [String: Fusion.Approval.Approver],
    author: String,
    coauthors: [String: String]
  ) -> Report.CreateThread { .init(
    template: fusion.createThread,
    report: .init(cfg: self, context: Report.ReviewCreated(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      review: review,
      users: users,
      author: author,
      coauthors: coauthors.isEmpty.else(coauthors)
    ))
  )}
  func reportReviewMergeConflicts(
    status: Fusion.Approval.Status,
    review: Json.GitlabReviewState,
    users: [String: Fusion.Approval.Approver]
  ) -> Report { .init(cfg: self, context: Report.ReviewMergeConflicts(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    thread: status.thread,
    review: review,
    users: users,
    author: status.author,
    coauthors: status.coauthors.isEmpty.else(status.coauthors)
  ))}
  func reportReviewClosed(
    status: Fusion.Approval.Status,
    review: Json.GitlabReviewState,
    users: [String: Fusion.Approval.Approver],
    reason: Report.ReviewClosed.Reason
  ) -> Report { .init(cfg: self, context: Report.ReviewClosed(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    thread: status.thread,
    review: review,
    users: users,
    author: status.author,
    coauthors: status.coauthors.isEmpty.else(status.coauthors),
    reason: reason
  ))}
  func reportReviewBlocked(
    status: Fusion.Approval.Status,
    review: Json.GitlabReviewState,
    users: [String: Fusion.Approval.Approver],
    reasons: [Report.ReviewBlocked.Reason]
  ) -> Report { .init(cfg: self, context: Report.ReviewBlocked(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    thread: status.thread,
    review: review,
    users: users,
    author: status.author,
    coauthors: status.coauthors.isEmpty.else(status.coauthors),
    reasons: reasons
  ))}
  func reportCustom(
    event: String,
    stdin: [String]
  ) -> Report { .init(cfg: self, context: Report.Custom(
    subevent: event,
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    stdin: stdin.isEmpty.else(stdin)
  ))}
  func reportReviewCustom(
    event: String,
    review: Json.GitlabReviewState,
    users: [String],
    stdin: [String]
  ) -> Report { .init(cfg: self, context: Report.ReviewCustom(
    subevent: event,
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    review: review,
    users: .init(users)
      .union([review.author.username]),
    stdin: stdin.isEmpty.else(stdin)
  ))}
  func reportUnexpected(
    error: Error
  ) -> Report { .init(cfg: self, context: Report.Unexpected(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    error: String(describing: error)
  ))}
  func reportUnownedCode(
    files: [String]
  ) -> Report { .init(cfg: self, context: Report.UnownedCode(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    files: files
  ))}
  func reportFileTaboos(
    issues: [FileTaboo.Issue]
  ) -> Report { .init(cfg: self, context: Report.FileTaboos(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    issues: issues
  ))}
  func reportReviewObsolete(
    files: [String]
  ) -> Report { .init(cfg: self, context: Report.ReviewObsolete(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    files: files
  ))}
  func reportForbiddenCommits(
    commits: [String]
  ) -> Report { .init(cfg: self, context: Report.ForbiddenCommits(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    commits: commits
  ))}
  func reportConflictMarkers(
    markers: [String]
  ) -> Report { .init(cfg: self, context: Report.ConflictMarkers(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    markers: markers
  ))}
  func reportReviewMerged(
    review: Json.GitlabReviewState,
    users: [String]
  ) -> Report { .init(cfg: self, context: Report.ReviewMerged(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    review: review,
    users: .init(users)
      .union([review.author.username])
  ))}
  func reportReviewMergeError(
    review: Json.GitlabReviewState,
    users: [String],
    error: String
  ) -> Report { .init(cfg: self, context: Report.ReviewMergeError(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    review: review,
    users: .init(users)
      .union([review.author.username]),
    error: error
  ))}
//  func reportEmergencyAwardApproval(
//    review: Json.GitlabReviewState,
//    users: Set<String>,
//    cheaters: Set<String>
//  ) -> Report { .init(cfg: self, context: Report.EmergencyAwardApproval(
//    env: env,
//    ctx: context,
//    info: try? gitlabCi.get().info,
//    review: review,
//    users: users,
//    cheaters: cheaters
//  ))}
//  func reportAwardApprovalReady(
//    review: Json.GitlabReviewState,
//    users: Set<String>
//  ) -> Report { .init(cfg: self, context: Report.AwardApprovalReady(
//    env: env,
//    ctx: context,
//    info: try? gitlabCi.get().info,
//    review: review,
//    users: users
//  ))}
//  func reportNewAwardApproval(
//    review: Json.GitlabReviewState,
//    users: Set<String>,
//    group: AwardApproval.Group.Report
//  ) -> Report { .init(cfg: self, context: Report.NewAwardApproval(
//    env: env,
//    ctx: context,
//    info: try? gitlabCi.get().info,
//    review: review,
//    users: users,
//    group: group
//  ))}
//  func reportWaitAwardApproval(
//    review: Json.GitlabReviewState,
//    users: Set<String>,
//    group: AwardApproval.Group.Report
//  ) -> Report { .init(cfg: self, context: Report.WaitAwardApproval(
//    env: env,
//    ctx: context,
//    info: try? gitlabCi.get().info,
//    review: review,
//    users: users,
//    group: group
//  ))}
//  func reportNewAwardApprovals(
//    review: Json.GitlabReviewState,
//    users: Set<String>,
//    groups: [AwardApproval.Group.Report]
//  ) -> Report { .init(cfg: self, context: Report.NewAwardApprovals(
//    env: env,
//    ctx: context,
//    info: try? gitlabCi.get().info,
//    review: review,
//    users: users,
//    groups: groups
//  ))}
//  func reportWaitAwardApprovals(
//    review: Json.GitlabReviewState,
//    users: Set<String>,
//    groups: [AwardApproval.Group.Report]
//  ) -> Report { .init(cfg: self, context: Report.WaitAwardApprovals(
//    env: env,
//    ctx: context,
//    info: try? gitlabCi.get().info,
//    review: review,
//    users: users,
//    groups: groups
//  ))}
//  func reportAwardApprovalHolders(
//    review: Json.GitlabReviewState,
//    users: Set<String>,
//    holders: Set<String>
//  ) -> Report { .init(cfg: self, context: Report.AwardApprovalHolders(
//    env: env,
//    ctx: context,
//    info: try? gitlabCi.get().info,
//    review: review,
//    users: users,
//    holders: holders
//  ))}
  func reportReleaseBranchCreated(
    ref: String,
    product: String,
    version: String
  ) -> Report { .init(cfg: self, context: Report.ReleaseBranchCreated(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    ref: ref,
    product: product,
    version: version
  ))}
  func reportHotfixBranchCreated(
    ref: String,
    product: String,
    version: String
  ) -> Report { .init(cfg: self, context: Report.HotfixBranchCreated(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    ref: ref,
    product: product,
    version: version
  ))}
  func reportDeployTagCreated(
    ref: String,
    product: Production.Product,
    deploy: Production.Build.Deploy,
    uniq: [Report.DeployTagCreated.Commit],
    heir: [Report.DeployTagCreated.Commit],
    lack: [Report.DeployTagCreated.Commit]
  ) -> Report { .init(cfg: self, context: Report.DeployTagCreated(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    ref: ref,
    product: product.name,
    deploy: deploy,
    uniq: uniq.isEmpty.else(uniq),
    heir: heir.isEmpty.else(heir),
    lack: lack.isEmpty.else(lack)
  ))}
  func reportVersionBumped(
    product: String,
    version: String
  ) -> Report { .init(cfg: self, context: Report.VersionBumped(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    product: product,
    version: version
  ))}
  func reportAccessoryBranchCreated(
    ref: String
  ) -> Report { .init(cfg: self, context: Report.AccessoryBranchCreated(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    ref: ref
  ))}
  func reportExpiringRequisites(
    items: [Report.ExpiringRequisites.Item]
  ) -> Report { .init(cfg: self, context: Report.ExpiringRequisites(
    env: env,
    ctx: context,
    info: try? gitlabCi.get().info,
    items: items
  ))}
}
