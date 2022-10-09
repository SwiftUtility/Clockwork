import Foundation
import Facility
public protocol GenerationContext: Encodable {
  var event: String { get }
  var subevent: String { get }
  var ctx: AnyCodable? { get }
  var info: GitlabCi.Info? { get }
}
public extension GenerationContext {
  static var event: String { "\(Self.self)" }
  var subevent: String { "" }
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
  }
  public struct CreateHotfixBranchName: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct CreateDeployTagName: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
    public var build: String
  }
  public struct CreateDeployTagAnnotation: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
    public var build: String
  }
  public struct BumpCurrentVersion: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct BumpBuildNumber: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var build: String
  }
  public struct ParseDeployTagVersion: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
  }
  public struct ParseDeployTagBuild: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
  }
  public struct CreateHotfixVersion: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct AdjustAccessoryBranchVersion: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct CreateVersionsCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct CreateBuildCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var build: String
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
    public var review: Json.GitlabReviewState
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
    public var source: String
    public var target: String
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
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.exportBuilds,
    templates: templates,
    context: Generate.ExportBuildContext(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      versions: versions,
      build: build
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
  func createDeployTagName(
    product: Production.Product,
    version: String,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.deploy.createName,
    templates: templates,
    context: Generate.CreateDeployTagName(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version,
      build: build
    )
  )}
  func createDeployTagAnnotation(
    product: Production.Product,
    version: String,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.deploy.createAnnotation,
    templates: templates,
    context: Generate.CreateDeployTagAnnotation(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version,
      build: build
    )
  )}
  func createReleaseBranchName(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.release.createName,
    templates: templates,
    context: Generate.CreateReleaseBranchName(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func createHotfixBranchName(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.hotfix.createName,
    templates: templates,
    context: Generate.CreateHotfixBranchName(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func bumpCurrentVersion(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.release.createVersion,
    templates: templates,
    context: Generate.BumpCurrentVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func bumpBuildNumber(
    production: Production,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.createBuild,
    templates: templates,
    context: Generate.BumpBuildNumber(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      build: build
    )
  )}
  func parseDeployTagVersion(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.deploy.parseVersion,
    templates: templates,
    context: Generate.ParseDeployTagVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      ref: ref
    )
  )}
  func parseDeployTagBuild(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.deploy.parseBuild,
    templates: templates,
    context: Generate.ParseDeployTagBuild(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      ref: ref
    )
  )}
  func createHotfixVersion(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.hotfix.createVersion,
    templates: templates,
    context: Generate.CreateHotfixVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func adjustAccessoryBranchVersion(
    accessoryBranch: Production.AccessoryBranch,
    ref: String,
    product: String,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: accessoryBranch.adjustVersion,
    templates: templates,
    context: Generate.AdjustAccessoryBranchVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product,
      version: version
    )
  )}
  func createVersionsCommitMessage(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.versions.createCommitMessage,
    templates: templates,
    context: Generate.CreateVersionsCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func createBuildCommitMessage(
    production: Production,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.builds.createCommitMessage,
    templates: templates,
    context: Generate.CreateBuildCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      build: build
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
    review: Json.GitlabReviewState
  ) -> Generate { .init(
    allowEmpty: false,
    template: fusion.approval.statuses.createCommitMessage,
    templates: templates,
    context: Generate.CreateFusionStatusesCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      review: review
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
      source: review.sourceBranch,
      target: review.targetBranch
    )
  )}
}
