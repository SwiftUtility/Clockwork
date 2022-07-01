import Foundation
import Facility
public struct Production {
  public var builds: Configuration.Asset
  public var versions: Configuration.Asset
  public var bumpBuildNumber: Configuration.Template
  public var products: [Product]
  public var deployTag: DeployTag
  public var releaseBranch: ReleaseBranch
  public var accessoryBranch: AccessoryBranch?
  public var maxBuildsCount: Int?
  public func productMatching(ref: String, tag: Bool) throws -> Product? {
    var product: Product? = nil
    let keyPath = tag.then(\Product.deployTagNameMatch).get(\Product.releaseBranchNameMatch)
    for value in products {
      guard value[keyPath: keyPath].isMet(ref) else { continue }
      if let product = product {
        throw Thrown("\(ref) matches both \(product.name) and \(value.name)")
      } else {
        product = value
      }
    }
    return product
  }
  public func productMatching(name: String) throws -> Product { try products
    .first(where: { $0.name == name })
    .get { throw Thrown("No product \(name)") }
  }
  public static func make(
    mainatiners: Set<String>,
    yaml: Yaml.Controls.Production
  ) throws -> Self { try .init(
    builds: .make(yaml: yaml.builds),
    versions: .make(yaml: yaml.versions),
    bumpBuildNumber: .make(yaml: yaml.bumpBuildNumber),
    products: yaml.products
      .map { name, yaml in try .init(
        name: name,
        mainatiners: mainatiners
          .union(Set(yaml.mainatiners.get([]))),
        deployTagNameMatch: .init(yaml: yaml.deployTagNameMatch),
        releaseBranchNameMatch: .init(yaml: yaml.releaseBranchNameMatch),
        bumpCurrentVersion: .make(yaml: yaml.bumpCurrentVersion),
        createHotfixVersion: .make(yaml: yaml.createHotfixVersion)
      )},
    deployTag: .init(
      createName: .make(yaml: yaml.deployTag.createName),
      createAnnotation: .make(yaml: yaml.deployTag.createAnnotation),
      parseBuild: .make(yaml: yaml.deployTag.parseBuild),
      parseVersion: .make(yaml: yaml.deployTag.parseVersion)
    ),
    releaseBranch: .init(
      createName: .make(yaml: yaml.releaseBranch.createName),
      parseVersion: .make(yaml: yaml.releaseBranch.parseVersion)
    ),
    accessoryBranch: yaml.accessoryBranch
      .map { yaml in try .init(
        mainatiners: yaml.mainatiners
          .map(Set.init(_:))
          .get([])
          .union(mainatiners),
        nameMatch: .init(yaml: yaml.nameMatch),
        createName: .make(yaml: yaml.createName),
        adjustVersion: .make(yaml: yaml.adjustVersion)
      )},
    maxBuildsCount: yaml.maxBuildsCount
  )}
  public struct Product {
    public var name: String
    public var mainatiners: Set<String>
    public var deployTagNameMatch: Criteria
    public var releaseBranchNameMatch: Criteria
    public var bumpCurrentVersion: Configuration.Template
    public var createHotfixVersion: Configuration.Template
    public func deploy(job: Json.GitlabJob, version: String, build: String) -> Build.Deploy {
      .init(build: build, sha: job.pipeline.sha, product: name, version: version)
    }
  }
  public struct DeployTag {
    public var createName: Configuration.Template
    public var createAnnotation: Configuration.Template
    public var parseBuild: Configuration.Template
    public var parseVersion: Configuration.Template
  }
  public struct ReleaseBranch {
    public var createName: Configuration.Template
    public var parseVersion: Configuration.Template
  }
  public struct AccessoryBranch {
    public var mainatiners: Set<String>
    public var nameMatch: Criteria
    public var createName: Configuration.Template
    public var adjustVersion: Configuration.Template
  }
  public enum Build {
    case review(Review)
    case branch(Branch)
    case deploy(Deploy)
    public var yaml: Yaml.Controls.Production.Build {
      switch self {
      case .review(let review): return .init(
        build: review.build,
        sha: review.sha,
        review: review.review,
        target: review.target
      )
      case .branch(let branch): return .init(
        build: branch.build,
        sha: branch.sha,
        branch: branch.branch
      )
      case .deploy(let deploy): return .init(
        build: deploy.build,
        sha: deploy.sha,
        product: deploy.product,
        version: deploy.version
      )}
    }
    public var build: String {
      switch self {
      case .review(let review): return review.build
      case .branch(let branch): return branch.build
      case .deploy(let deploy): return deploy.build
      }
    }
    public var target: String? {
      guard case .review(let review) = self else { return nil }
      return review.target
    }
    public static func make(yaml: Yaml.Controls.Production.Build) throws -> Self {
      if let deploy = try? Deploy.make(yaml: yaml) { return .deploy(deploy) }
      else if let branch = try? Branch.make(yaml: yaml) { return .branch(branch) }
      else if let review = try? Review.make(yaml: yaml) { return .review(review) }
      else { throw Thrown("Wrong build format") }
    }
    public struct Review: Encodable {
      public var build: String
      public var sha: String
      public var review: UInt
      public var target: String
      public static func make(yaml: Yaml.Controls.Production.Build) throws -> Self {
        guard yaml.branch == nil, yaml.product == nil, yaml.version == nil else { throw Thrown() }
        return try .init(
          build: yaml.build,
          sha: yaml.sha,
          review: ?!yaml.review,
          target: ?!yaml.target
        )
      }
    }
    public struct Branch: Encodable {
      public var build: String
      public var sha: String
      public var branch: String
      public static func make(yaml: Yaml.Controls.Production.Build) throws -> Self {
        guard yaml.review == nil, yaml.product == nil, yaml.version == nil else { throw Thrown() }
        return try .init(build: yaml.build, sha: yaml.sha, branch: ?!yaml.branch)
      }
    }
    public struct Deploy: Encodable {
      public var build: String
      public var sha: String
      public var product: String
      public var version: String
      public static func make(yaml: Yaml.Controls.Production.Build) throws -> Self {
        guard yaml.review == nil, yaml.branch == nil else { throw Thrown() }
        return try .init(
          build: yaml.build,
          sha: yaml.sha,
          product: ?!yaml.product,
          version: ?!yaml.version
        )
      }
    }
  }
}
