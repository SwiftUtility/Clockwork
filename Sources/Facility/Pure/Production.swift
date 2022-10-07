import Foundation
import Facility
public struct Production {
  public var builds: Configuration.Asset
  public var versions: Configuration.Asset
  public var deliveries: Configuration.Asset
  public var bumpBuildNumber: Configuration.Template
  public var exportBuild: Configuration.Template
  public var exportVersions: Configuration.Template
  public var createReleaseThread: Configuration.Template
  public var createHotfixThread: Configuration.Template
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
    yaml: Yaml.Production
  ) throws -> Self { try .init(
    builds: .make(yaml: yaml.builds),
    versions: .make(yaml: yaml.versions),
    deliveries: .make(yaml: yaml.deliveries),
    bumpBuildNumber: .make(yaml: yaml.bumpBuildNumber),
    exportBuild: .make(yaml: yaml.exportBuild),
    exportVersions: .make(yaml: yaml.exportVersions),
    createReleaseThread: .make(yaml: yaml.createReleaseThread),
    createHotfixThread: .make(yaml: yaml.createHotfixThread),
    products: yaml.products
      .map { name, yaml in try .init(
        name: name,
        deployTagNameMatch: .init(yaml: yaml.deployTagNameMatch),
        releaseBranchNameMatch: .init(yaml: yaml.releaseBranchNameMatch),
        releaseNoteMatch: yaml.releaseNoteMatch
          .map(Criteria.init(yaml:))
          .get(.init()),
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
        nameMatch: .init(yaml: yaml.nameMatch),
        adjustVersion: .make(yaml: yaml.adjustVersion)
      )},
    maxBuildsCount: yaml.maxBuildsCount
  )}
  public struct Product {
    public var name: String
    public var deployTagNameMatch: Criteria
    public var releaseBranchNameMatch: Criteria
    public var releaseNoteMatch: Criteria
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
    public var nameMatch: Criteria
    public var adjustVersion: Configuration.Template
  }
  public enum Build {
    case review(Review)
    case branch(Branch)
    case deploy(Deploy)
    public var yaml: String {
      switch self {
      case .review(let review): return review.yaml.joined()
      case .branch(let branch): return branch.yaml.joined()
      case .deploy(let deploy): return deploy.yaml.joined()
      }
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
    public static func make(yaml: Yaml.Production.Build) throws -> Self {
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
      public var yaml: [String] { [
        "- build: '\(build)'\n",
        "  sha: '\(sha)'\n",
        "  review: \(review)\n",
        "  target: \(target)\n",
      ]}
      public static func make(yaml: Yaml.Production.Build) throws -> Self {
        guard yaml.branch == nil, yaml.product == nil, yaml.version == nil else { throw Thrown() }
        return try .init(
          build: yaml.build,
          sha: yaml.sha,
          review: ?!yaml.review,
          target: ?!yaml.target
        )
      }
      public static func make(
        build: String,
        sha: String,
        review: UInt,
        target: String
      ) -> Self { .init(
        build: build,
        sha: sha,
        review: review,
        target: target
      )}
    }
    public struct Branch: Encodable {
      public var build: String
      public var sha: String
      public var branch: String
      public var yaml: [String] { [
        "- build: '\(build)'\n",
        "  sha: '\(sha)'\n",
        "  branch: \(branch)\n",
      ]}
      public static func make(yaml: Yaml.Production.Build) throws -> Self {
        guard yaml.review == nil, yaml.product == nil, yaml.version == nil else { throw Thrown() }
        return try .init(build: yaml.build, sha: yaml.sha, branch: ?!yaml.branch)
      }
    }
    public struct Deploy: Encodable {
      public var build: String
      public var sha: String
      public var product: String
      public var version: String
      public var yaml: [String] { [
        "- build: '\(build)'\n",
        "  sha: '\(sha)'\n",
        "  product: \(product)\n",
        "  version: \(version)\n",
      ]}
      public static func make(yaml: Yaml.Production.Build) throws -> Self {
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
  public typealias Deliveries = [String: [Delivery]]
  public struct Delivery {
    public var release: Shipment
    public var hotfixes: [Shipment]
    public static func make(yaml: Yaml.Production.Delivery) throws -> Self { try .init(
      release: .make(yaml: yaml.release),
      hotfixes: yaml.hotfixes
        .get([])
        .map(Shipment.make(yaml:))
    )}
    public static func shipment(
      deliveries: Deliveries,
      product: String,
      version: String
    ) -> Shipment? { deliveries[product]
      .get([])
      .reversed()
      .flatMap({ $0.hotfixes.reversed() + [$0.release] })
      .first(where: { $0.version == version })
    }
    public static func record(
      deliveries: inout Deliveries,
      product: String,
      release version: String,
      start: Git.Sha,
      thread: Yaml.Thread
    ) throws {
      deliveries[product] = deliveries[product].get([]) + [.init(
        release: .init(start: start, version: version, thread: .make(yaml: thread), deploys: []),
        hotfixes: []
      )]
    }
    public static func record(
      deliveries: inout Deliveries,
      product: String,
      release: String,
      hotfix: Shipment
    ) throws {
      guard let index = deliveries[product]?.firstIndex(where: { $0.release.version == release })
      else { throw Thrown("No release \(release) for \(product)") }
      deliveries[product]?[index].hotfixes.append(hotfix)
    }
    public static func record(
      deliveries: inout Deliveries,
      product: String,
      version: String,
      deploy: Git.Sha
    ) throws {
      for release in deliveries[product].get([]).indices.reversed() {
        if deliveries[product]?[release].release.version == version {
          deliveries[product]?[release].release.deploys.insert(deploy)
          return
        }
        for hotfix in deliveries[product].get([])[release].hotfixes.indices.reversed() {
          if deliveries[product]?[release].hotfixes[hotfix].version == version {
            deliveries[product]?[release].hotfixes[hotfix].deploys.insert(deploy)
            return
          }
        }
      }
      throw Thrown("No release \(version) for \(product)")
    }
    public static func serialize(deliveries: Deliveries) -> String {
      guard deliveries.isEmpty.not else { return "{}\n" }
      var result: String = ""
      for product in deliveries.keys.sorted() {
        guard let deliveries = deliveries[product], deliveries.isEmpty.not else { continue }
        result += "'\(product)':\n"
        for delivery in deliveries {
          result += "- release:\n"
          result += delivery.release.serialize(hotfix: false)
          if delivery.hotfixes.isEmpty.not {
            result += "  hotfixes:\n"
            result += delivery.hotfixes.map({ $0.serialize(hotfix: true) }).joined()
          }
        }
      }
      return result
    }
    public struct Shipment {
      public var start: Git.Sha
      public var version: String
      public var thread: Configuration.Thread
      public var deploys: Set<Git.Sha>
      public func serialize(hotfix: Bool) -> String {
        var result: String = ""
        result += "  \(hotfix.then("-").get(" ")) start: '\(start.value)'\n"
        result += "    thread: {channel: '\(thread.channel)', ts: '\(thread.ts)'}\n"
        result += "    version: '\(version)'\n"
        if deploys.isEmpty.not {
          result += "    deploys:\n"
          result += deploys
            .map(\.value)
            .sorted()
            .map({"    - '\($0)'\n"})
            .joined()
        }
        return result
      }
      public static func make(yaml: Yaml.Production.Delivery.Shipment) throws -> Self { try .init(
        start: .make(value: yaml.start),
        version: yaml.version,
        thread: .make(yaml: yaml.thread),
        deploys: Set(yaml.deploys
          .get([])
          .map(Git.Sha.make(value:))
        )
      )}
    }
  }
}
