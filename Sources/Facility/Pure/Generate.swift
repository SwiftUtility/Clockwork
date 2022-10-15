import Foundation
import Facility
public protocol GenerationContext: Encodable {
  var event: String { get }
  var subevent: String { get }
  var env: [String: String] { get set }
  var ctx: AnyCodable? { get set }
  var info: GitlabCi.Info? { get set }
  var mark: String? { get set }
}
public extension GenerationContext {
  static var event: String { "\(Self.self)" }
  var subevent: String { "" }
  var mark: String? { get { "" } set {} }
  var identity: String { subevent.isEmpty
    .then("\(Self.self)")
    .get("\(Self.self)/\(subevent)")
  }
}
public struct Generate: Query {
  public var allowEmpty: Bool
  public var template: Configuration.Template
  public var templates: [String: String]
  public var context: GenerationContext
  public typealias Reply = String
  public struct ExportCurrentVersions: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var versions: [String: String]
  }
  public struct ExportBuildContext: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
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
  public struct ExportIntegrationTargets: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var fork: String
    public var source: String
    public var targets: [String]
  }
  public struct CreateReleaseBranchName: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
    public var hotfix: Bool
  }
  public struct CreateTagName: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
    public var build: String
    public var deploy: Bool
  }
  public struct CreateTagAnnotation: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
    public var build: String
    public var deploy: Bool
  }
  public struct BumpReleaseVersion: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
    public var hotfix: Bool
  }
  public struct BumpBuildNumber: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var build: String
  }
  public struct ParseReleaseBranchVersion: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var ref: String
  }
  public struct ParseTagVersion: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var ref: String
    public var deploy: Bool
  }
  public struct ParseTagBuild: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var ref: String
    public var deploy: Bool
  }
  public struct CreateVersionsCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
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
  public struct CreateBuildCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var build: String
    public var review: String?
    public var branch: String?
    public var tag: String?
  }
  public struct CreateApproversCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var user: String
    public var active: Bool
  }
  public struct CreateReviewQueueCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
    public var queued: Bool
  }
  public struct CreateFusionStatusesCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState?
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
    }
  }
  public struct CreatePropositionCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
  }
  public struct CreateIntegrationCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var fork: String
    public var source: String
    public var target: String
  }
  public struct CreateReplicationCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var fork: String
    public var source: String
    public var target: String
  }
  public struct CreateFusionMergeCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
  }
}
public extension Configuration {
  func exportCurrentVersions(
    production: Production,
    versions: [String: String]
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.exportVersions,
    templates: templates,
    context: Generate.ExportCurrentVersions(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      versions: versions
    )
  )}
  func exportBuildContext(
    production: Production,
    versions: [String: String],
    build: String,
    kind: Generate.ExportBuildContext.Kind
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.exportBuilds,
    templates: templates,
    context: Generate.ExportBuildContext(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      versions: versions,
      build: build,
      kind: kind
    )
  )}
  func exportIntegrationTargets(
    integration: Fusion.Integration,
    fork: Git.Sha,
    source: String,
    targets: [String]
  ) -> Generate { .init(
    allowEmpty: false,
    template: integration.exportAvailableTargets,
    templates: templates,
    context: Generate.ExportIntegrationTargets(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      fork: fork.value,
      source: source,
      targets: targets
    )
  )}
  func createTagName(
    product: Production.Product,
    version: String,
    build: String,
    deploy: Bool
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.createTagName,
    templates: templates,
    context: Generate.CreateTagName(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version,
      build: build,
      deploy: deploy
    )
  )}
  func createTagAnnotation(
    product: Production.Product,
    version: String,
    build: String,
    deploy: Bool
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.createTagAnnotation,
    templates: templates,
    context: Generate.CreateTagAnnotation(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version,
      build: build,
      deploy: deploy
    )
  )}
  func createReleaseBranchName(
    product: Production.Product,
    version: String,
    hotfix: Bool
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.createReleaseBranchName,
    templates: templates,
    context: Generate.CreateReleaseBranchName(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version,
      hotfix: hotfix
    )
  )}
  func bumpReleaseVersion(
    product: Production.Product,
    version: String,
    hotfix: Bool
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.bumpReleaseVersion,
    templates: templates,
    context: Generate.BumpReleaseVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version,
      hotfix: hotfix
    )
  )}
  func bumpBuildNumber(
    production: Production,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.bumpBuildNumber,
    templates: templates,
    context: Generate.BumpBuildNumber(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      build: build
    )
  )}
  func parseReleaseBranchVersion(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.parseBranchVersion,
    templates: templates,
    context: Generate.ParseReleaseBranchVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      ref: ref
    )
  )}
  func parseTagVersion(
    product: Production.Product,
    ref: String,
    deploy: Bool
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.parseTagVersion,
    templates: templates,
    context: Generate.ParseTagVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      ref: ref,
      deploy: deploy
    )
  )}
  func parseTagBuild(
    product: Production.Product,
    ref: String,
    deploy: Bool
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.parseTagBuild,
    templates: templates,
    context: Generate.ParseTagBuild(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      ref: ref,
      deploy: deploy
    )
  )}
  func createVersionsCommitMessage(
    production: Production,
    product: String?,
    version: String?,
    reason: Generate.CreateVersionsCommitMessage.Reason
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.versions.createCommitMessage,
    templates: templates,
    context: Generate.CreateVersionsCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product,
      version: version,
      reason: reason
    )
  )}
  func createBuildCommitMessage(
    production: Production,
    build: Production.Build
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.builds.createCommitMessage,
    templates: templates,
    context: Generate.CreateBuildCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      build: build.build.value,
      review: build.review,
      branch: build.branch,
      tag: build.tag
    )
  )}
  func createApproversCommitMessage(
    fusion: Fusion,
    user: String,
    active: Bool
  ) -> Generate { .init(
    allowEmpty: false,
    template: fusion.approval.approvers.createCommitMessage,
    templates: templates,
    context: Generate.CreateApproversCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      user: user,
      active: active
    )
  )}
  func createReviewQueueCommitMessage(
    fusion: Fusion,
    review: Json.GitlabReviewState,
    queued: Bool
  ) -> Generate { .init(
    allowEmpty: false,
    template: fusion.queue.createCommitMessage,
    templates: templates,
    context: Generate.CreateReviewQueueCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      review: review,
      queued: queued
    )
  )}
  func createFusionStatusesCommitMessage(
    fusion: Fusion,
    review: Json.GitlabReviewState?,
    reason: Generate.CreateFusionStatusesCommitMessage.Reason
  ) -> Generate { .init(
    allowEmpty: false,
    template: fusion.approval.statuses.createCommitMessage,
    templates: templates,
    context: Generate.CreateFusionStatusesCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      review: review,
      reason: reason
    )
  )}
  func createPropositionCommitMessage(
    proposition: Fusion.Proposition,
    review: Json.GitlabReviewState
  ) -> Generate { .init(
    allowEmpty: false,
    template: proposition.createCommitMessage,
    templates: templates,
    context: Generate.CreatePropositionCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      review: review
    )
  )}
  func createIntegrationCommitMessage(
    integration: Fusion.Integration,
    merge: Fusion.Merge
  ) -> Generate { .init(
    allowEmpty: false,
    template: integration.createCommitMessage,
    templates: templates,
    context: Generate.CreateIntegrationCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
  func createReplicationCommitMessage(
    replication: Fusion.Replication,
    merge: Fusion.Merge
  ) -> Generate { .init(
    allowEmpty: false,
    template: replication.createCommitMessage,
    templates: templates,
    context: Generate.CreateReplicationCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
  func createFusionMergeCommitMessage(
    fusion: Fusion,
    review: Json.GitlabReviewState
  ) -> Generate { .init(
    allowEmpty: false,
    template: fusion.createMergeCommitMessage,
    templates: templates,
    context: Generate.CreateFusionMergeCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      review: review
    )
  )}
}
