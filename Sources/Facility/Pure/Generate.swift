import Foundation
import Facility
public protocol GenerateContext: Encodable {
  static var allowEmpty: Bool { get }
  static var name: String { get }
}
public extension GenerateContext {
  static var allowEmpty: Bool { false }
  static var name: String { "\(Self.self)" }
}
public protocol GenerateInfo: Encodable {
  var event: [String] { get }
  var args: [String]? { get }
  var allowEmpty: Bool { get }
  var env: [String: String] { get set }
  var gitlab: Gitlab.Info? { get set }
  var mark: String? { get set }
  var jira: Jira.Info? { get set }
  var slack: Slack.Info? { get set }
}
public extension GenerateInfo {
  func match(signal: Slack.Signal) -> Bool { signal.events.lazy
    .filter({ event.count <= $0.count })
    .contains(where: { zip(event, $0).contains(where: !=).not })
  }
  func match(create: Slack.Thread) -> Bool { match(signal: create.create) }
  func match(update: Slack.Thread) -> [Slack.Signal] { update.update.filter(match(signal:)) }
}
public struct Generate: Query {
  public var template: Configuration.Template
  public var templates: [String: String]
  public var info: GenerateInfo
  public typealias Reply = String
  public struct Info<Context: GenerateContext>: GenerateInfo {
    public let event: [String]
    public let args: [String]?
    public var ctx: Context
    public var env: [String: String] = [:]
    public var gitlab: Gitlab.Info? = nil
    public var jira: Jira.Info? = nil
    public var slack: Slack.Info? = nil
    public var mark: String? = nil
    public var allowEmpty: Bool { Context.allowEmpty }
    static func make(
      cfg: Configuration,
      context: Context,
      subevent: [String],
      args: [String]?
    ) -> Self { .init(
      event: [Context.name] + subevent,
      args: args,
      ctx: context
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
    public var update: [UInt]? = nil
    public var delete: [UInt]? = nil
    public var enqueue: [UInt]? = nil
    public var dequeue: [UInt]? = nil
  }
  public struct CreateMergeCommitMessage: GenerateContext {
    public var review: UInt?
    public var kind: String?
    public var fork: String?
    public var original: String?
  }
}
public extension Configuration {
  func report(template: Configuration.Template, info: GenerateInfo) -> Generate {
    .init(template: template, templates: templates, info: info)
  }
  func exportVersions(
    flow: Flow,
    args: [String],
    versions: [String: String],
    build: String?,
    kind: Generate.ExportVersions.Kind?
  ) -> Generate { generate(
    template: flow.exportVersions,
    ctx: Generate.ExportVersions(versions: versions, build: build, kind: kind),
    args: args
  )}
  func createFlowBuildsCommitMessage(
    builds: Flow.Builds,
    build: Flow.Build
  ) -> Generate { generate(
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
  ) -> Generate { generate(
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
  ) -> Generate { generate(
    template: builds.bump,
    ctx: Generate.BumpBuildNumber(build: build)
  )}
  func createTagName(
    flow: Flow,
    product: String,
    version: String,
    build: String?,
    deploy: Bool
  ) -> Generate { generate(
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
  ) -> Generate { generate(
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
  ) -> Generate { generate(
    template: flow.createReleaseBranchName,
    ctx: Generate.CreateReleaseBranchName(product: product, version: version, hotfix: hotfix)
  )}
  func bumpReleaseVersion(
    flow: Flow,
    product: String,
    version: String,
    hotfix: Bool
  ) -> Generate { generate(
    template: flow.versions.bump,
    ctx: Generate.BumpReleaseVersion(product: product, version: version, hotfix: hotfix)
  )}
  func createGitlabStorageCommitMessage(
    user: String,
    gitlab: Gitlab,
    command: Gitlab.Storage.Command
  ) -> Generate { generate(
    template: gitlab.storage.asset.createCommitMessage,
    ctx: Generate.CreateGitlabStorageCommitMessage(user: user, reason: command.reason)
  )}
  func createReviewStorageCommitMessage(
    storage: Review.Storage,
    context: Generate.CreateReviewStorageCommitMessage
  ) -> Generate { generate(
    template: storage.asset.createCommitMessage,
    ctx: context
  )}
  func createMergeCommitMessage(
    merge: Json.GitlabMergeState?,
    review: Review,
    fusion: Review.Fusion?
  ) -> Generate { generate(
    template: review.createMessage,
    ctx: Generate.CreateMergeCommitMessage(
      review: merge?.iid,
      kind: fusion?.kind,
      fork: fusion?.fork?.value,
      original: fusion?.original?.name
    ),
    merge: merge
  )}
  func exportTargets(
    review: Review,
    fork: Git.Sha,
    source: String,
    integrate: [String],
    duplicate: [String],
    propogate: [String],
    args: [String]
  ) -> Generate { generate(
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
private extension Configuration {
  func generate<Context: GenerateContext>(
    template: Configuration.Template,
    ctx: Context,
    merge: Json.GitlabMergeState? = nil,
    subevent: [String] = [],
    args: [String]? = nil
  ) -> Generate {
    var info = Generate.Info.make(cfg: self, context: ctx, subevent: subevent, args: args)
    info.env = env
    info.gitlab = try? gitlab.get().info
    info.gitlab?.merge = merge.flatMapNil(try? gitlab.get().merge.get())
    info.jira = try? jira.get().info
    return .init(template: template, templates: templates, info: info)
  }
}
