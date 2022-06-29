import Foundation
import Facility
public protocol GenerationContext: Encodable {
  var event: String { get set }
  var subevent: String? { get }
  var ctx: AnyCodable? { get }
  var info: GitlabCi.Info? { get }
}
public extension GenerationContext {
  static var event: String { "\(Self.self)" }
  var subevent: String? { nil }
  var adjusted: Self {
    guard let subevent = subevent else { return self }
    var result = self
    result.event = "\(event)/\(subevent)"
    return result
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
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var versions: [String: String]
  }
  public struct ExportBuildContext: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var versions: [String: String]
    public var build: String
  }
  public struct ExportIntegrationTargets: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var targets: [String]
  }
  public struct ParseReleaseBranchVersion: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var ref: String
  }
  public struct CreateReleaseBranchName: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct CreateDeployTagName: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
    public var build: String
  }
  public struct CreateDeployTagAnnotation: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
    public var build: String
  }
  public struct BumpCurrentVersion: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct BumpBuildNumber: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var build: String
  }
  public struct ParseDeployTagVersion: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var ref: String
  }
  public struct ParseDeployTagBuild: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var ref: String
  }
  public struct CreateHotfixVersion: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct AdjustAccessoryBranchVersion: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var family: String
    public var product: String
    public var version: String
  }
  public struct CreateVersionCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct CreateBuildCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var build: String
  }
  public struct CreateUserActivityCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var user: String
    public var active: Bool
  }
  public struct CreateResolutionCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var review: Json.GitlabReviewState
  }
  public struct CreateIntegrationCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var fork: String
    public var source: String
    public var target: String
  }
  public struct CreateReplicationCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var fork: String
    public var source: String
    public var target: String
  }
}
public extension Configuration {
  func exportCurrentVersions(
    versions: [String: String]
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: profile.exportCurrentVersions.get(),
    templates: profile.templates,
    context: Generate.ExportCurrentVersions(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      versions: versions
    )
  )}
  func exportBuildContext(
    versions: [String: String],
    build: String
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: profile.exportBuildContext.get(),
    templates: profile.templates,
    context: Generate.ExportBuildContext(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      versions: versions,
      build: build
    )
  )}
  func exportIntegrationTargets(
    targets: [String]
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: profile.exportIntegrationTargets.get(),
    templates: profile.templates,
    context: Generate.ExportIntegrationTargets(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      targets: targets
    )
  )}
  func parseReleaseBranchVersion(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.releaseBranch.parseVersion,
    templates: controls.templates,
    context: Generate.ParseReleaseBranchVersion(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
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
      info: try? controls.gitlabCi.get().info,
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
    template: product.deployTag.createAnnotation,
    templates: controls.templates,
    context: Generate.CreateDeployTagAnnotation(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
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
    template: product.releaseBranch.createName,
    templates: controls.templates,
    context: Generate.CreateReleaseBranchName(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func bumpCurrentVersion(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.bumpCurrentVersion,
    templates: controls.templates,
    context: Generate.BumpCurrentVersion(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func bumpBuildNumber(
    production: Production,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.bumpBuildNumber,
    templates: controls.templates,
    context: Generate.BumpBuildNumber(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      build: build
    )
  )}
  func parseDeployTagVersion(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.deployTag.parseVersion,
    templates: controls.templates,
    context: Generate.ParseDeployTagVersion(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      product: product.name,
      ref: ref
    )
  )}
  func parseDeployTagBuild(
    product: Production.Product,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.deployTag.parseBuild,
    templates: controls.templates,
    context: Generate.ParseDeployTagBuild(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      product: product.name,
      ref: ref
    )
  )}
  func createHotfixVersion(
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: product.createHotfixVersion,
    templates: controls.templates,
    context: Generate.CreateHotfixVersion(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
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
    templates: controls.templates,
    context: Generate.AdjustAccessoryBranchVersion(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      family: accessoryBranch.family,
      product: product,
      version: version
    )
  )}
  func createVersionCommitMessage(
    asset: Asset,
    product: Production.Product,
    version: String
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: asset.createCommitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: controls.templates,
    context: Generate.CreateVersionCommitMessage(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func createBuildCommitMessage(
    asset: Asset,
    build: String
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: asset.createCommitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: controls.templates,
    context: Generate.CreateBuildCommitMessage(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      build: build
    )
  )}
  func createUserActivityCommitMessage(
    asset: Asset,
    user: String,
    active: Bool
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: asset.createCommitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: controls.templates,
    context: Generate.CreateUserActivityCommitMessage(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      user: user,
      active: active
    )
  )}
  func createResolutionCommitMessage(
    resolution: Fusion.Resolution,
    review: Json.GitlabReviewState
  ) -> Generate { .init(
    allowEmpty: false,
    template: resolution.createCommitMessage,
    templates: controls.templates,
    context: Generate.CreateResolutionCommitMessage(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      review: review
    )
  )}
  func createIntegrationCommitMessage(
    integration: Fusion.Integration,
    merge: Fusion.Merge
  ) -> Generate { .init(
    allowEmpty: false,
    template: integration.createCommitMessage,
    templates: controls.templates,
    context: Generate.CreateIntegrationCommitMessage(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
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
    templates: controls.templates,
    context: Generate.CreateReplicationCommitMessage(
      ctx: controls.context,
      info: try? controls.gitlabCi.get().info,
      fork: merge.fork.value,
      source: merge.source.name,
      target: merge.target.name
    )
  )}
}
