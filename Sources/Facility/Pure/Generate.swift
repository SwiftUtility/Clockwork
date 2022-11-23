import Foundation
import Facility
public protocol GenerateContext: Encodable {
  var subevent: [String] { get }
  static var allowEmpty: Bool { get }
  static var name: String { get }
}
public extension GenerateContext {
  var subevent: [String] { [] }
  static var allowEmpty: Bool { false }
  static var name: String { "\(Self.self)" }
}
public protocol GenerateInfo: Encodable {
  var event: [String] { get }
  var env: [String: String] { get set }
  var gitlab: Gitlab.Context? { get set }
  var mark: String? { get set }
  var jira: Jira.Context? { get set }
  var slack: Slack.Context? { get set }
  var allowEmpty: Bool { get }
}
public struct Generate: Query {
  public var template: Configuration.Template
  public var templates: [String: String]
  public var info: GenerateInfo
  public static func make<Context: GenerateContext>(
    cfg: Configuration,
    template: Configuration.Template,
    ctx: Context,
    subevent: [String]? = nil
  ) -> Self { .init(
    template: template,
    templates: cfg.templates,
    info: Info.make(context: ctx, subevent: subevent.get(ctx.subevent))
  )}
  public typealias Reply = String
  public struct Info<Context: GenerateContext>: GenerateInfo {
    public let event: [String]
    public var ctx: Context
    public var env: [String: String] = [:]
    public var gitlab: Gitlab.Context? = nil
    public var mark: String? = nil
    public var kind: String? = nil
    public var jira: Jira.Context? = nil
    public var slack: Slack.Context? = nil
    public var allowEmpty: Bool { Context.allowEmpty }
    public static func make(context: Context, subevent: [String]) -> Self { .init(
      event: [Context.name] + subevent,
      ctx: context
    )}
  }
  public struct ExportCurrentVersions: GenerateContext {
    public var versions: [String: String]
  }
  public struct ExportBuildContext: GenerateContext {
    public var versions: [String: String]
    public var build: String
    public var kind: Kind
    public enum Kind: String, Encodable {
      case stage
      case deploy
      case review
      case branch
    }
  }
  public struct ExportIntegrationTargets: GenerateContext {
    public var fork: String
    public var source: String
    public var targets: [String]
  }
  public struct CreateReleaseBranchName: GenerateContext {
    public var product: String
    public var version: String
    public var hotfix: Bool
  }
  public struct CreateTagName: GenerateContext {
    public var product: String
    public var version: String
    public var build: String
    public var deploy: Bool
  }
  public struct CreateTagAnnotation: GenerateContext {
    public var product: String
    public var version: String
    public var build: String
    public var deploy: Bool
  }
  public struct BumpReleaseVersion: GenerateContext {
    public var product: String
    public var version: String
    public var hotfix: Bool
  }
  public struct BumpBuildNumber: GenerateContext {
    public var build: String
  }
  public struct ParseReleaseBranchVersion: GenerateContext {
    public var product: String
    public var ref: String
  }
  public struct ParseTagVersion: GenerateContext {
    public var product: String
    public var ref: String
    public var deploy: Bool
  }
  public struct ParseTagBuild: GenerateContext {
    public var product: String
    public var ref: String
    public var deploy: Bool
  }
  public struct CreateVersionsCommitMessage: GenerateContext {
    public var product: String?
    public var version: String?
    public var reason: Reason
    public enum Reason: String, Encodable {
      case deploy
      case hotfix
      case release
      case changeNext
      case changeAccessory
      case deleteAccessory
      case revokeRelease
    }
  }
  public struct CreateBuildCommitMessage: GenerateContext {
    public var build: String
    public var review: String?
    public var branch: String?
    public var tag: String?
  }
  public struct CreateApproversCommitMessage: GenerateContext {
    public var user: String
    public var reason: Reason
    public enum Reason: String, Encodable {
      case activate
      case deactivate
      case register
      case unwatchAuthors
      case unwatchTeams
      case watchAuthors
      case watchTeams
    }
  }
  public struct CreateReviewQueueCommitMessage: GenerateContext {
    public var queued: Bool
  }
  public struct CreateFusionStatusesCommitMessage: GenerateContext {
    public var reason: Reason
    public enum Reason: String, Encodable {
      case create
      case merge
      case close
      case update
      case clean
      case cheat
      case approve
      case own
      case skipCommit
      case unown
    }
  }
  public struct CreateMergeCommitMessage: GenerateContext {}
  public struct CreateFusionCommitMessage: GenerateContext {
    public var kind: String
    public var fork: String?
    public var original: String?
  }
}
public extension Production {
  func exportCurrentVersions(
    cfg: Configuration,
    versions: [String: String]
  ) -> Generate { .make(
    cfg: cfg,
    template: exportVersions,
    ctx: Generate.ExportCurrentVersions(versions: versions)
  )}
  func exportBuildContext(
    cfg: Configuration,
    versions: [String: String],
    build: String,
    kind: Generate.ExportBuildContext.Kind
  ) -> Generate { .make(
    cfg: cfg,
    template: exportBuilds,
    ctx: Generate.ExportBuildContext(versions: versions, build: build, kind: kind)
  )}
  func createVersionsCommitMessage(
    cfg: Configuration,
    product: String?,
    version: String?,
    reason: Generate.CreateVersionsCommitMessage.Reason
  ) -> Generate { .make(
    cfg: cfg,
    template: versions.createCommitMessage,
    ctx: Generate.CreateVersionsCommitMessage(product: product, version: version, reason: reason)
  )}
  func createBuildCommitMessage(
    cfg: Configuration,
    build: Production.Build
  ) -> Generate { .make(
    cfg: cfg,
    template: builds.createCommitMessage,
    ctx: Generate.CreateBuildCommitMessage(
      build: build.build.value,
      review: build.review,
      branch: build.branch,
      tag: build.tag
    )
  )}
  func bumpBuildNumber(
    cfg: Configuration,
    build: String
  ) -> Generate { .make(
    cfg: cfg,
    template: bumpBuildNumber,
    ctx: Generate.BumpBuildNumber(build: build)
  )}
}
public extension Production.Product {
  func createTagName(
    cfg: Configuration,
    version: String,
    build: String,
    deploy: Bool
  ) -> Generate { .make(
    cfg: cfg,
    template: createTagName,
    ctx: Generate.CreateTagName(
      product: name,
      version: version,
      build: build,
      deploy: deploy
    )
  )}
  func createTagAnnotation(
    cfg: Configuration,
    version: String,
    build: String,
    deploy: Bool
  ) -> Generate { .make(
    cfg: cfg,
    template: createTagAnnotation,
    ctx: Generate.CreateTagAnnotation(
      product: name,
      version: version,
      build: build,
      deploy: deploy
    )
  )}
  func createReleaseBranchName(
    cfg: Configuration,
    version: String,
    hotfix: Bool
  ) -> Generate { .make(
    cfg: cfg,
    template: createReleaseBranchName,
    ctx: Generate.CreateReleaseBranchName(product: name, version: version, hotfix: hotfix)
  )}
  func bumpReleaseVersion(
    cfg: Configuration,
    version: String,
    hotfix: Bool
  ) -> Generate { .make(
    cfg: cfg,
    template: bumpReleaseVersion,
    ctx: Generate.BumpReleaseVersion(product: name, version: version, hotfix: hotfix)
  )}
  func parseReleaseBranchVersion(
    cfg: Configuration,
    ref: String
  ) -> Generate { .make(
    cfg: cfg,
    template: parseBranchVersion,
    ctx: Generate.ParseReleaseBranchVersion(product: name, ref: ref)
  )}
  func parseTagVersion(
    cfg: Configuration,
    ref: String,
    deploy: Bool
  ) -> Generate { .make(
    cfg: cfg,
    template: parseTagVersion,
    ctx: Generate.ParseTagVersion(product: name, ref: ref, deploy: deploy)
  )}
  func parseTagBuild(
    cfg: Configuration,
    ref: String,
    deploy: Bool
  ) -> Generate { .make(
    cfg: cfg,
    template: parseTagBuild,
    ctx: Generate.ParseTagBuild(product: name, ref: ref, deploy: deploy)
  )}
}
public extension Fusion {
  func createApproversCommitMessage(
    cfg: Configuration,
    user: String,
    command: Fusion.Approval.Approver.Command
  ) -> Generate { .make(
    cfg: cfg,
    template: approval.approvers.createCommitMessage,
    ctx: Generate.CreateApproversCommitMessage(user: user, reason: command.reason)
  )}
  func createReviewQueueCommitMessage(
    cfg: Configuration,
    queued: Bool
  ) -> Generate { .make(
    cfg: cfg,
    template: queue.createCommitMessage,
    ctx: Generate.CreateReviewQueueCommitMessage(queued: queued)
  )}
  func createFusionStatusesCommitMessage(
    cfg: Configuration,
    reason: Generate.CreateFusionStatusesCommitMessage.Reason
  ) -> Generate { .make(
    cfg: cfg,
    template: approval.statuses.createCommitMessage,
    ctx: Generate.CreateFusionStatusesCommitMessage(reason: reason)
  )}
  func createMergeCommitMessage(cfg: Configuration) -> Generate { .make(
    cfg: cfg,
    template: createCommitMessage,
    ctx: Generate.CreateMergeCommitMessage()
  )}
  func exportIntegrationTargets(
    cfg: Configuration,
    fork: Git.Sha,
    source: String,
    targets: [String]
  ) -> Generate { .make(
    cfg: cfg,
    template: integration.exportAvailableTargets,
    ctx: Generate.ExportIntegrationTargets(fork: fork.value, source: source, targets: targets)
  )}
}
public extension Review.State.Infusion {
  func createFusionCommitMessage(cfg: Configuration) -> Generate { .make(
    cfg: cfg,
    template: createCommitMessage,
    ctx: Generate.CreateFusionCommitMessage(
      kind: prefix,
      fork: merge?.fork.value,
      original: merge?.original.name
    )
  )}
}
