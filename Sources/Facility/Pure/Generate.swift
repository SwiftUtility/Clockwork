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
  var args: [String]? { get set }
  var gitlab: Gitlab.Info? { get set }
  var mark: String? { get set }
  var jira: Jira.Info? { get set }
  var slack: Slack.Info? { get set }
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
    subevent: [String]? = nil,
    args: [String]? = nil,
    merge: Json.GitlabMergeState? = nil
  ) -> Self { .init(
    template: template,
    templates: cfg.templates,
    info: Info.make(cfg: cfg, context: ctx, args: args, merge: merge)
  )}
  public typealias Reply = String
  public struct Info<Context: GenerateContext>: GenerateInfo {
    public let event: [String]
    public var ctx: Context
    public var env: [String: String]
    public var gitlab: Gitlab.Info?
    public var jira: Jira.Info?
    public var args: [String]?
    public var mark: String? = nil
    public var kind: String? = nil
    public var slack: Slack.Info? = nil
    public var allowEmpty: Bool { Context.allowEmpty }
    public static func make(
      cfg: Configuration,
      context: Context,
      args: [String]?,
      subevent: [String]? = nil,
      merge: Json.GitlabMergeState?
    ) -> Self { .init(
      event: [Context.name] + subevent.get(context.subevent),
      ctx: context,
      env: cfg.env,
      gitlab: try? cfg.gitlab.get().info(merge: merge),
      jira: try? cfg.jira.get().info,
      args: args
    )}
  }
  public struct ExportVersions: GenerateContext {
    public var versions: [String: String]
    public var build: String?
    public var kind: Kind?
    public enum Kind: String, Encodable {
      case stage
      case deploy
      case review
      case branch
    }
  }
  public struct ExportMergeTargets: GenerateContext {
    public var fork: String
    public var source: String
    public var integrate: [String]?
    public var duplicate: [String]?
    public var propogate: [String]?
  }
  public struct CreateReleaseBranchName: GenerateContext {
    public var product: String
    public var version: String
    public var hotfix: Bool
  }
  public struct CreateTagName: GenerateContext {
    public var product: String
    public var version: String
    public var build: String?
    public var deploy: Bool
  }
  public struct CreateTagAnnotation: GenerateContext {
    public var product: String
    public var version: String
    public var build: String?
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
  public struct CreateFlowBuildsCommitMessage: GenerateContext {
    public var build: String
    public var review: String?
    public var branch: String?
    public var tag: String?
  }
  public struct CreateFlowVersionsCommitMessage: GenerateContext {
    public var product: String?
    public var version: String?
    public var ref: String?
    public var reason: Reason
    public enum Reason: String, Encodable {
      case deploy
      case hotfix
      case release
      case changeNext
      case changeAccessory
      case deleteAccessory
//      case reserveReviewBuild
//      case reserveBranchBuild
    }
  }
  public struct CreateGitlabStorageCommitMessage: GenerateContext {
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
  public struct CreateReviewStorageCommitMessage: GenerateContext {
    public var reason: Reason
    public enum Reason: String, Encodable {
      case create
      case merge
      case close
//      case update
//      case clean
      case cheat
      case approve
      case own
      case patch
      case unown
      case dequeue
      case enqueue
    }
  }
  public struct CreateMergeCommitMessage: GenerateContext {
    public var kind: String?
    public var fork: String?
    public var original: String?
  }
}
public extension Configuration {
  func exportVersions(
    flow: Flow,
    args: [String],
    versions: [String: String],
    build: String?,
    kind: Generate.ExportVersions.Kind?
  ) -> Generate { .make(
    cfg: self,
    template: flow.exportVersions,
    ctx: Generate.ExportVersions(versions: versions, build: build, kind: kind),
    args: args
  )}
  func createFlowBuildsCommitMessage(
    builds: Flow.Builds,
    build: Flow.Build
  ) -> Generate { .make(
    cfg: self,
    template: builds.storage.createCommitMessage,
    ctx: Generate.CreateFlowBuildsCommitMessage(
      build: build.number.value,
      review: build.review.map({ "\($0)" }),
      branch: build.branch?.name,
      tag: build.tag?.name
    )
  )}
  func createFlowVersionsCommitMessage(
    flow: Flow,
    product: String? = nil,
    version: String? = nil,
    ref: String? = nil,
    reason: Generate.CreateFlowVersionsCommitMessage.Reason
  ) -> Generate { .make(
    cfg: self,
    template: flow.versions.storage.createCommitMessage,
    ctx: Generate.CreateFlowVersionsCommitMessage(
      product: product,
      version: version,
      ref: ref,
      reason: reason
    )
  )}
  func bumpBuildNumber(
    builds: Flow.Builds,
    build: String
  ) -> Generate { .make(
    cfg: self,
    template: builds.bump,
    ctx: Generate.BumpBuildNumber(build: build)
  )}
  func createTagName(
    flow: Flow,
    product: String,
    version: String,
    build: String?,
    deploy: Bool
  ) -> Generate { .make(
    cfg: self,
    template: flow.createTagName,
    ctx: Generate.CreateTagName(
      product: product,
      version: version,
      build: build,
      deploy: deploy
    )
  )}
  func createTagAnnotation(
    flow: Flow,
    product: String,
    version: String,
    build: String?,
    deploy: Bool
  ) -> Generate { .make(
    cfg: self,
    template: flow.createTagAnnotation,
    ctx: Generate.CreateTagAnnotation(
      product: product,
      version: version,
      build: build,
      deploy: deploy
    )
  )}
  func createReleaseBranchName(
    flow: Flow,
    product: String,
    version: String,
    hotfix: Bool
  ) -> Generate { .make(
    cfg: self,
    template: flow.createReleaseBranchName,
    ctx: Generate.CreateReleaseBranchName(product: product, version: version, hotfix: hotfix)
  )}
  func bumpReleaseVersion(
    flow: Flow,
    product: String,
    version: String,
    hotfix: Bool
  ) -> Generate { .make(
    cfg: self,
    template: flow.versions.bump,
    ctx: Generate.BumpReleaseVersion(product: product, version: version, hotfix: hotfix)
  )}
  func createGitlabStorageCommitMessage(
    user: String,
    gitlab: Gitlab,
    command: Gitlab.Storage.Command
  ) -> Generate { .make(
    cfg: self,
    template: gitlab.storage.asset.createCommitMessage,
    ctx: Generate.CreateGitlabStorageCommitMessage(user: user, reason: command.reason)
  )}
  func createReviewStorageCommitMessage(
    storage: Review.Storage,
    reason: Generate.CreateReviewStorageCommitMessage.Reason
  ) -> Generate { .make(
    cfg: self,
    template: storage.asset.createCommitMessage,
    ctx: Generate.CreateReviewStorageCommitMessage(reason: reason)
  )}
  #warning("tbd add context")
  func createMergeCommitMessage(
    review: Review,
    fusion: Review.Fusion?
  ) -> Generate { .make(
    cfg: self,
    template: review.createMessage,
    ctx: Generate.CreateMergeCommitMessage(
      kind: fusion?.kind,
      fork: fusion?.fork?.value,
      original: fusion?.original?.name
    )
  )}
  func exportTargets(
    review: Review,
    fork: Git.Sha,
    source: String,
    integrate: [String],
    duplicate: [String],
    propogate: [String],
    args: [String]
  ) -> Generate { .make(
    cfg: self,
    template: review.exportTargets,
    ctx: Generate.ExportMergeTargets(
      fork: fork.value,
      source: source,
      integrate: integrate.isEmpty.not.then(integrate),
      duplicate: duplicate.isEmpty.not.then(duplicate),
      propogate: propogate.isEmpty.not.then(propogate)
    ),
    args: args.isEmpty.else(args)
  )}
}
