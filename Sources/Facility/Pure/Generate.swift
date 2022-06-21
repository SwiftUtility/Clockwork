import Foundation
import Facility
public struct Generate: Query {
  public var template: String
  public var templates: [String: String]
  public var context: Encodable
  public typealias Reply = String
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
  public struct SquashCommitMessage: Encodable {
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
    template: String,
    versions: [String: String]
  ) -> Generate { .init(
    template: template,
    templates: profile.templates,
    context: Generate.Versions(
      ctx: controls.context,
      versions: versions
    )
  )}
  func generateBuild(
    template: String,
    versions: [String: String],
    build: Production.Build
  ) -> Generate { .init(
    template: template,
    templates: profile.templates,
    context: Generate.Build(
      ctx: controls.context,
      versions: versions,
      build: build
    )
  )}
  func generateIntegration(
    template: String,
    targets: [String]
  ) -> Generate { .init(
    template: template,
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
    template: product.releaseBranch.parseVersionTemplate,
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
    template: product.deployTag.createTemplate,
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
    template: product.deployTag.createTemplate,
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
    template: product.releaseBranch.createTemplate,
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
    template: product.createNextVersionTemplate,
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
    template: production.createNextBuildTemplate,
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
    template: product.deployTag.parseVersionTemplate,
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
    template: product.deployTag.parseBuildTemplate,
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
    template: product.createHotfixVersionTemplate,
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
  ) -> Generate { .init(
    template: asset.commitMessageTemplate,
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
  ) -> Generate { .init(
    template: asset.commitMessageTemplate,
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
  ) -> Generate { .init(
    template: asset.commitMessageTemplate,
    templates: controls.templates,
    context: Generate.UserActivityCommitMessage(
      ctx: controls.context,
      user: user,
      active: active
    )
  )}
  func generateSquashCommitMessage(
    squash: Flow.Squash,
    review: Json.GitlabReviewState
  ) -> Generate { .init(
    template: squash.messageTemplate,
    templates: controls.templates,
    context: Generate.SquashCommitMessage(
      ctx: controls.context,
      review: review
    )
  )}
  func generateIntegrationCommitMessage(
    integration: Flow.Integration,
    merge: Flow.Merge
  ) -> Generate { .init(
    template: integration.messageTemplate,
    templates: controls.templates,
    context: Generate.IntegrationCommitMessage(
      ctx: controls.context,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
  func generateReplicationCommitMessage(
    replication: Flow.Replication,
    merge: Flow.Merge
  ) -> Generate { .init(
    template: replication.messageTemplate,
    templates: controls.templates,
    context: Generate.ReplicationCommitMessage(
      ctx: controls.context,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
}
