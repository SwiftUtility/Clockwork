import Foundation
import Facility
public struct Generate: Query {
  public var template: String
  public var templates: [String: String]
  public var context: Encodable
  public typealias Reply = String
  public struct Versions: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var versions: [String: String]
  }
  public struct Build: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var versions: [String: String]
    public var build: String
  }
  public struct Integration: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var targets: [String]
  }
  public struct ReleaseVersion: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var ref: String
  }
  public struct ReleaseName: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct DeployName: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
    public var build: String
  }
  public struct DeployAnnotation: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var product: String
    public var version: String
    public var build: String
  }
  public struct NextVersion: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct NextBuild: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var build: String
  }
  public struct DeployVersion: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var ref: String
  }
  public struct DeployBuild: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var ref: String
  }
  public struct HotfixVersion: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct VersionCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var product: String
    public var version: String
  }
  public struct BuildCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var build: String
  }
  public struct UserActivityCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var user: String
    public var active: Bool
  }
  public struct SquashCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var review: Json.GitlabReviewState
  }
  public struct IntegrationCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
    public var fork: String
    public var source: String
    public var target: String
  }
  public struct ReplicationCommitMessage: Codable {
    public var env: [String: String]
    public var custom: AnyCodable?
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
      env: env,
      custom: controls.context,
      versions: versions
    )
  )}
  func generateBuild(
    template: String,
    build: String,
    versions: [String: String]
  ) -> Generate { .init(
    template: template,
    templates: profile.templates,
    context: Generate.Build(
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
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
      env: env,
      custom: controls.context,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
}
