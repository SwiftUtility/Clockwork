import Foundation
import Facility
public struct Generate: Query {
  public var template: Configuration.Template
  public var templates: [String: String]
  public var context: Encodable
  public typealias Reply = String
  public struct Custom: Encodable {
    public var ctx: AnyCodable?
    public var yaml: AnyCodable?
  }
  public struct Versions: Encodable {
    public var ctx: AnyCodable?
    public var versions: [String: String]
  }
  public struct Build: Encodable {
    public var ctx: AnyCodable?
    public var versions: [String: String]
    public var build: Production.Build
  }
  public struct Integration: Encodable {
    public var ctx: AnyCodable?
    public var targets: [String]
  }
  public struct ReleaseVersion: Encodable {
    public var ctx: AnyCodable?
    public var product: String
    public var ref: String
  }
  public struct ReleaseName: Encodable {
    public var ctx: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct DeployName: Encodable {
    public var ctx: AnyCodable?
    public var product: String
    public var version: String
    public var build: String
  }
  public struct DeployAnnotation: Encodable {
    public var ctx: AnyCodable?
    public var user: String
    public var product: String
    public var version: String
    public var build: String
  }
  public struct NextVersion: Encodable {
    public var ctx: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct NextBuild: Encodable {
    public var ctx: AnyCodable?
    public var build: String
  }
  public struct DeployVersion: Encodable {
    public var ctx: AnyCodable?
    public var product: String
    public var ref: String
  }
  public struct DeployBuild: Encodable {
    public var ctx: AnyCodable?
    public var ref: String
  }
  public struct HotfixVersion: Encodable {
    public var ctx: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct VersionCommitMessage: Encodable {
    public var ctx: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct BuildCommitMessage: Encodable {
    public var ctx: AnyCodable?
    public var build: String
  }
  public struct UserActivityCommitMessage: Encodable {
    public var ctx: AnyCodable?
    public var user: String
    public var active: Bool
  }
  public struct ResolutionCommitMessage: Encodable {
    public var ctx: AnyCodable?
    public var review: Json.GitlabReviewState
  }
  public struct IntegrationCommitMessage: Encodable {
    public var ctx: AnyCodable?
    public var fork: String
    public var source: String
    public var target: String
  }
  public struct ReplicationCommitMessage: Encodable {
    public var ctx: AnyCodable?
    public var fork: String
    public var source: String
    public var target: String
  }
}
public extension Configuration {
  func generateVersions(
    versions: [String: String]
  ) throws -> Generate { try .init(
    template: profile.renderVersions.get(),
    templates: profile.templates,
    context: Generate.Versions(
      ctx: controls.context,
      versions: versions
    )
  )}
  func generateBuild(
    versions: [String: String],
    build: Production.Build
  ) throws -> Generate { try .init(
    template: profile.renderBuild.get(),
    templates: profile.templates,
    context: Generate.Build(
      ctx: controls.context,
      versions: versions,
      build: build
    )
  )}
  func generateIntegration(
    targets: [String]
  ) throws -> Generate { try .init(
    template: profile.renderIntegration.get(),
    templates: profile.templates,
    context: Generate.Integration(
      ctx: controls.context,
      targets: targets
    )
  )}
  func generateReleaseVersion(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    template: product.releaseBranch.parseVersion,
    templates: controls.templates,
    context: Generate.ReleaseVersion(
      ctx: controls.context,
      product: product.name,
      ref: ref
    )
  )}
  func generateDeployName(
    product: Production.Product,
    version: String,
    build: String
  ) -> Generate { .init(
    template: product.deployTag.generateName,
    templates: controls.templates,
    context: Generate.DeployName(
      ctx: controls.context,
      product: product.name,
      version: version,
      build: build
    )
  )}
  func generateDeployAnnotation(
    job: Json.GitlabJob,
    product: Production.Product,
    version: String,
    build: String
  ) -> Generate { .init(
    template: product.deployTag.generateName,
    templates: controls.templates,
    context: Generate.DeployAnnotation(
      ctx: controls.context,
      user: job.user.username,
      product: product.name,
      version: version,
      build: build
    )
  )}
  func generateReleaseName(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    template: product.releaseBranch.generateName,
    templates: controls.templates,
    context: Generate.ReleaseName(
      ctx: controls.context,
      product: product.name,
      version: version
    )
  )}
  func generateNextVersion(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
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
    template: product.generateHotfixVersion,
    templates: controls.templates,
    context: Generate.HotfixVersion(
      ctx: controls.context,
      product: product.name,
      version: version
    )
  )}
  func generateVersionCommitMessage(
    asset: Asset,
    product: Production.Product,
    version: String
  ) throws -> Generate { try .init(
    template: asset.commitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: controls.templates,
    context: Generate.VersionCommitMessage(
      ctx: controls.context,
      product: product.name,
      version: version
    )
  )}
  func generateBuildCommitMessage(
    asset: Asset,
    build: String
  ) throws -> Generate { try .init(
    template: asset.commitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: controls.templates,
    context: Generate.BuildCommitMessage(
      ctx: controls.context,
      build: build
    )
  )}
  func generateUserActivityCommitMessage(
    asset: Asset,
    user: String,
    active: Bool
  ) throws -> Generate { try .init(
    template: asset.commitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: controls.templates,
    context: Generate.UserActivityCommitMessage(
      ctx: controls.context,
      user: user,
      active: active
    )
  )}
  func generateResolutionCommitMessage(
    resolution: Fusion.Resolution,
    review: Json.GitlabReviewState
  ) -> Generate { .init(
    template: resolution.commitMessage,
    templates: controls.templates,
    context: Generate.ResolutionCommitMessage(
      ctx: controls.context,
      review: review
    )
  )}
  func generateIntegrationCommitMessage(
    integration: Fusion.Integration,
    merge: Fusion.Merge
  ) -> Generate { .init(
    template: integration.commitMessage,
    templates: controls.templates,
    context: Generate.IntegrationCommitMessage(
      ctx: controls.context,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
  func generateReplicationCommitMessage(
    replication: Fusion.Replication,
    merge: Fusion.Merge
  ) -> Generate { .init(
    template: replication.commitMessage,
    templates: controls.templates,
    context: Generate.ReplicationCommitMessage(
      ctx: controls.context,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
}
