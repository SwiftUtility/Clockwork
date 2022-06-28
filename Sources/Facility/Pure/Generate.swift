import Foundation
import Facility
public protocol GenerationContext: Encodable {
  var event: String { get }
  var ctx: AnyCodable? { get }
}
public extension GenerationContext {
  static var event: String { "\(Self.self)" }
}
public struct Generate: Query {
  public var allowEmpty: Bool
  public var template: Configuration.Template
  public var templates: [String: String]
  public var context: GenerationContext
  public typealias Reply = String
  public struct RenderVersions: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var versions: [String: String]
  }
  public struct RenderBuild: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var versions: [String: String]
    public var build: String
  }
  public struct RenderIntegrationTargets: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info
    public var targets: [String]
  }
  public struct ParseReleaseVersion: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var product: String
    public var ref: String
  }
  public struct ReleaseName: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct AccessoryName: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var family: String
    public var custom: String
  }
  public struct CreateDeployTagName: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var product: String
    public var version: String
    public var build: String
  }
  public struct DeployAnnotation: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info
    public var product: String
    public var version: String
    public var build: String
  }
  public struct NextVersion: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct NextBuild: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var build: String
  }
  public struct DeployVersion: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var product: String
    public var ref: String
  }
  public struct DeployBuild: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var ref: String
  }
  public struct HotfixVersion: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct AdjustAccessoryVersion: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var ref: String
    public var family: String
    public var product: String
    public var version: String
  }
  public struct VersionCommitMessage: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info
    public var product: String
    public var version: String
  }
  public struct BuildCommitMessage: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info
    public var build: String
  }
  public struct UserActivityCommitMessage: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info
    public var user: String
    public var active: Bool
  }
  public struct ResolutionCommitMessage: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info
    public var review: Json.GitlabReviewState
  }
  public struct IntegrationCommitMessage: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info
    public var fork: String
    public var source: String
    public var target: String
  }
  public struct ReplicationCommitMessage: GenerationContext {
    public let event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info
    public var fork: String
    public var source: String
    public var target: String
  }
}
public extension Configuration {
  func renderVersions(
    versions: [String: String]
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: profile.renderVersions.get(),
    templates: profile.templates,
    context: Generate.RenderVersions(
      ctx: controls.context,
      versions: versions
    )
  )}
  func renderBuild(
    versions: [String: String],
    build: String
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: profile.renderBuild.get(),
    templates: profile.templates,
    context: Generate.RenderBuild(
      ctx: controls.context,
      versions: versions,
      build: build
    )
  )}
  func renderIntegrationTargets(
    targets: [String]
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: profile.renderIntegrationTargets.get(),
    templates: profile.templates,
    context: Generate.RenderIntegrationTargets(
      ctx: controls.context,
      info: controls.gitlabCi.get().info,
      targets: targets
    )
  )}
  func parseReleaseVersion(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.releaseBranch.parseVersion,
    templates: controls.templates,
    context: Generate.ParseReleaseVersion(
      ctx: controls.context,
      product: product.name,
      ref: ref
    )
  )}
  func createDeployTagName(
    product: Production.Product,
    version: String,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.deployTag.createName,
    templates: controls.templates,
    context: Generate.CreateDeployTagName(
      ctx: controls.context,
      product: product.name,
      version: version,
      build: build
    )
  )}
  func generateDeployAnnotation(
    product: Production.Product,
    version: String,
    build: String
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: product.deployTag.createAnnotation,
    templates: controls.templates,
    context: Generate.DeployAnnotation(
      ctx: controls.context,
      info: controls.gitlabCi.get().info,
      product: product.name,
      version: version,
      build: build
    )
  )}
  func generateReleaseName(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.releaseBranch.createName,
    templates: controls.templates,
    context: Generate.ReleaseName(
      ctx: controls.context,
      product: product.name,
      version: version
    )
  )}
  func generateAccessoryName(
    accessoryBranch: Production.AccessoryBranch,
    custom: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: accessoryBranch.createName,
    templates: controls.templates,
    context: Generate.AccessoryName(
      ctx: controls.context,
      family: accessoryBranch.family,
      custom: custom
    )
  )}
  func generateNextVersion(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.generateNextVersion,
    templates: controls.templates,
    context: Generate.NextVersion(
      ctx: controls.context,
      product: product.name,
      version: version
    )
  )}
  func generateNextBuild(
    production: Production,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.generateNextBuild,
    templates: controls.templates,
    context: Generate.NextBuild(
      ctx: controls.context,
      build: build
    )
  )}
  func generateDeployVersion(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.deployTag.parseVersion,
    templates: controls.templates,
    context: Generate.DeployVersion(
      ctx: controls.context,
      product: product.name,
      ref: ref
    )
  )}
  func generateDeployBuild(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.deployTag.parseBuild,
    templates: controls.templates,
    context: Generate.DeployBuild(
      ctx: controls.context,
      ref: ref
    )
  )}
  func generateHotfixVersion(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.generateHotfixVersion,
    templates: controls.templates,
    context: Generate.HotfixVersion(
      ctx: controls.context,
      product: product.name,
      version: version
    )
  )}
  func adjustAccessoryVersion(
    accessory: Production.AccessoryBranch,
    ref: String,
    product: String,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: accessory.adjustProductVersion,
    templates: controls.templates,
    context: Generate.AdjustAccessoryVersion(
      ctx: controls.context,
      ref: ref,
      family: accessory.family,
      product: product,
      version: version
    )
  )}
  func generateVersionCommitMessage(
    asset: Asset,
    product: Production.Product,
    version: String
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: asset.commitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: controls.templates,
    context: Generate.VersionCommitMessage(
      ctx: controls.context,
      info: controls.gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func generateBuildCommitMessage(
    asset: Asset,
    build: String
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: asset.commitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: controls.templates,
    context: Generate.BuildCommitMessage(
      ctx: controls.context,
      info: controls.gitlabCi.get().info,
      build: build
    )
  )}
  func generateUserActivityCommitMessage(
    asset: Asset,
    user: String,
    active: Bool
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: asset.commitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: controls.templates,
    context: Generate.UserActivityCommitMessage(
      ctx: controls.context,
      info: controls.gitlabCi.get().info,
      user: user,
      active: active
    )
  )}
  func generateResolutionCommitMessage(
    resolution: Fusion.Resolution,
    review: Json.GitlabReviewState
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: resolution.commitMessage,
    templates: controls.templates,
    context: Generate.ResolutionCommitMessage(
      ctx: controls.context,
      info: controls.gitlabCi.get().info,
      review: review
    )
  )}
  func generateIntegrationCommitMessage(
    integration: Fusion.Integration,
    merge: Fusion.Merge
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: integration.commitMessage,
    templates: controls.templates,
    context: Generate.IntegrationCommitMessage(
      ctx: controls.context,
      info: controls.gitlabCi.get().info,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
  func generateReplicationCommitMessage(
    replication: Fusion.Replication,
    merge: Fusion.Merge
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: replication.commitMessage,
    templates: controls.templates,
    context: Generate.ReplicationCommitMessage(
      ctx: controls.context,
      info: controls.gitlabCi.get().info,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
}
