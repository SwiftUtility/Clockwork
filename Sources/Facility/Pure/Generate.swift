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
  public struct ParseReleaseBranchVersion: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var ref: String
  }
  public struct CreateReleaseBranchName: GenerationContext {
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
  public struct CreateAccessoryBranchName: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var suffix: String
  }
  public struct AdjustAccessoryBranchVersion: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var product: String
    public var version: String
  }
  public struct CreateVersionCommitMessage: GenerationContext {
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
  public struct CreateUserActivityCommitMessage: GenerationContext {
    public var event: String = Self.event
    public var env: [String: String]
    public var ctx: AnyCodable?
    public var info: GitlabCi.Info?
    public var user: String
    public var active: Bool
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
    template: production.exportBuild,
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
  func parseReleaseBranchVersion(
    production: Production,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.releaseBranch.parseVersion,
    templates: templates,
    context: Generate.ParseReleaseBranchVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      ref: ref
    )
  )}
  func createDeployTagName(
    production: Production,
    product: Production.Product,
    version: String,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.deployTag.createName,
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
    production: Production,
    product: Production.Product,
    version: String,
    build: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.deployTag.createAnnotation,
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
    production: Production,
    product: Production.Product,
    version: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.releaseBranch.createName,
    templates: templates,
    context: Generate.CreateReleaseBranchName(
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
    template: product.bumpCurrentVersion,
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
    template: production.bumpBuildNumber,
    templates: templates,
    context: Generate.BumpBuildNumber(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      build: build
    )
  )}
  func parseDeployTagVersion(
    production: Production,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.deployTag.parseVersion,
    templates: templates,
    context: Generate.ParseDeployTagVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      ref: ref
    )
  )}
  func parseDeployTagBuild(
    production: Production,
    ref: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: production.deployTag.parseBuild,
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
    template: product.createHotfixVersion,
    templates: templates,
    context: Generate.CreateHotfixVersion(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      product: product.name,
      version: version
    )
  )}
  func createAccessoryBranchName(
    accessoryBranch: Production.AccessoryBranch,
    suffix: String
  ) -> Generate { .init(
    allowEmpty: false,
    template: accessoryBranch.createName,
    templates: templates,
    context: Generate.CreateAccessoryBranchName(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      suffix: suffix
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
  func createVersionCommitMessage(
    asset: Asset,
    product: Production.Product,
    version: String
  ) throws -> Generate { try .init(
    allowEmpty: false,
    template: asset.createCommitMessage
      .get { throw Thrown("CommitMessage not configured") },
    templates: templates,
    context: Generate.CreateVersionCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
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
    templates: templates,
    context: Generate.CreateBuildCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
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
    templates: templates,
    context: Generate.CreateUserActivityCommitMessage(
      env: env,
      ctx: context,
      info: try? gitlabCi.get().info,
      user: user,
      active: active
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
