import Foundation
import Facility
public struct Flow {
  public var storage: Configuration.Asset
  public var buildCount: Int
  public var releaseCount: Int
  public var bumpBuild: Configuration.Template
  public var bumpVersion: Configuration.Template
  public var exportVersions: Configuration.Template
  public var createTagName: Configuration.Template
  public var createTagAnnotation: Configuration.Template
  public var createReleaseBranchName: Configuration.Template
  public static func make(
    yaml: Yaml.Flow
  ) throws -> Self { try .init(
    storage: .make(yaml: yaml.storage),
    buildCount: max(10, yaml.buildCount),
    releaseCount: max(3, yaml.releaseCount),
    bumpBuild: .make(yaml: yaml.bumpBuild),
    bumpVersion: .make(yaml: yaml.bumpVersion),
    exportVersions: .make(yaml: yaml.exportVersions),
    createTagName: .make(yaml: yaml.createTagName),
    createTagAnnotation: .make(yaml: yaml.createTagAnnotation),
    createReleaseBranchName: .make(yaml: yaml.createReleaseBranchName)
  )}
  public struct Storage {
    public var stages: [Git.Tag: Stage] = [:]
    public var deploys: [Git.Tag: Deploy] = [:]
    public var families: [String: Family] = [:]
    public var products: [String: Product] = [:]
    public var releases: [Git.Branch: Release] = [:]
    public var accessories: [Git.Branch: Accessory] = [:]
    public mutating func change(product: String, nextVersion: String) throws {
      guard var product = products[product]
      else { throw Thrown("Not configured product: \(product)") }
      let nextVersion = nextVersion.alphaNumeric
      guard product.nextVersion != nextVersion
      else { throw Thrown("\(product.name) nextVersion is already \(nextVersion)") }
      guard product.prevVersions.contains(where: { $0 >= nextVersion }).not
      else { throw Thrown("\(product.name) \(nextVersion) is not the latest") }
      product.nextVersion = nextVersion
      products[product.name] = product
    }
    public mutating func change(accessory: Git.Branch, product: String, version: String) throws {
      guard products[product] != nil
      else { throw Thrown("Not configured product: \(product)") }
      guard var accessory = accessories[accessory]
      else { throw Thrown("No accessory branch: \(accessory)") }
      accessory.versions[product] = version.alphaNumeric
      accessories[accessory.branch] = accessory
    }
    public func version(product: Product, build: Build) -> AlphaNumeric? {
      if let release = releases[build.branch], release.product == product.name {
        return release.version
      } else {
        return accessories[build.branch]?.versions[product.name]
      }
    }
    public func kind(release: Release) -> Release.Kind {
      guard let product = products[release.product] else { return .hotfix }
      return product.prevVersions.contains(release.version).then(.release).get(.hotfix)
    }
    public func product(name: String) throws -> Product {
      try products[name].get(make: { throw Thrown("No product \(name)") })
    }
    public func family(name: String) throws -> Family {
      try families[name].get(make: { throw Thrown("No family \(name)") })
    }
    public func release(deploy: Deploy) -> Release? { releases.values
        .first(where: { $0.product == deploy.product && $0.version == deploy.version })
    }
    public func serialize(flow: Flow) -> String {
      var result = ""
      var versions: [String: AlphaNumeric] = [:]
      let yamlProducts = products.keys.sorted().compactMap({ products[$0] })
      result += "products:\(yamlProducts.isEmpty.then(" {}").get(""))\n"
      for product in yamlProducts {
        result += "  '\(product.name)':\n"
        result += "    family: '\(product.family)'\n"
        result += "    nextVersion: '\(product.nextVersion.value)'\n"
        let prev = product.prevVersions
          .sorted()
          .suffix(flow.releaseCount)
        versions[product.name] = prev.first.get(product.nextVersion)
        if prev.isEmpty.not {
          result += "    prevVersions: ['\(prev.map(\.value).joined(separator: "','"))']\n"
        }
      }
      let yamlReleases = releases.keys.sorted().compactMap({ releases[$0] })
      result += "releases:\(yamlReleases.isEmpty.then(" {}").get(""))\n"
      for release in yamlReleases {
        result += "  '\(release.branch.name)':\n"
        result += "    commit: '\(release.start.value)'\n"
        result += "    product: '\(release.product)'\n"
        result += "    version: '\(release.version.value)'\n"
      }
      let yamlDeploys = deploys.keys.sorted()
        .compactMap({ deploys[$0] })
        .filter({ deploy in versions[deploy.product].map({ deploy.version >= $0 }).get(false) })
      result += "deploys:\(yamlDeploys.isEmpty.then(" {}").get(""))\n"
      for deploy in yamlDeploys {
        result += "  '\(deploy.tag.name)':\n"
        result += "    build: '\(deploy.build.value)'\n"
        result += "    version: '\(deploy.version.value)'\n"
        result += "    product: '\(deploy.product)'\n"
      }
      let yamlAccessories = accessories.keys.sorted().compactMap({ accessories[$0] })
      result += "accessories:\(yamlAccessories.isEmpty.then(" {}").get(""))\n"
      for accessory in yamlAccessories {
        result += "  '\(accessory.branch.name)':\(accessory.versions.isEmpty.then(" {}").get(""))\n"
        for product in accessory.versions.keys.sorted() {
          guard let version = accessory.versions[product] else { continue }
          result += "    '\(product)': '\(version.value)'\n"
        }
      }
      let yamlStages = stages.keys.sorted().compactMap({ stages[$0] })
      result += "stages:\(yamlStages.isEmpty.then(" {}").get(""))\n"
      for stage in yamlStages {
        result += "  '\(stage.tag.name)':\n"
        result += "    build: '\(stage.build.value)'\n"
        result += "    version: '\(stage.version.value)'\n"
        result += "    product: '\(stage.product)'\n"
        result += "    branch: '\(stage.branch.name)'\n"
        result += "    product: '\(stage.product)'\n"
        result += stage.review.map({ "    review: \($0)\n" }).get("")
      }
      let yamlFamilies = families.keys.sorted().compactMap({ families[$0] })
      result += "families:\(yamlFamilies.isEmpty.then(" {}").get(""))\n"
      for family in yamlFamilies {
        result += "  '\(family.name)':\n"
        result += "    nextBuild: '\(family.nextBuild.value)'\n"
        let prev = family.builds.keys.sorted()
          .compactMap({ family.builds[$0] })
          .suffix(flow.buildCount)
        if prev.isEmpty.not { result += "    prevBuilds:\n" }
        for build in prev {
          result += "      '\(build.number.value)':\n"
          result += "        commit: '\(build.commit.value)'\n"
          result += "        branch: '\(build.branch.name)'\n"
          if let review = build.review {
            result += "        review: \(review)\n"
          }
        }
      }
      return result
    }
    public static var empty: Self { .init() }
    public static func make(yaml: Yaml.Flow.Storage) throws -> Self { try .init(
      stages: yaml.stages.map(Stage.make(tag:yaml:)).indexed(\.tag),
      deploys: yaml.deploys.map(Deploy.make(tag:yaml:)).indexed(\.tag),
      families: yaml.families.map(Family.make(name:yaml:)).indexed(\.name),
      products: yaml.products.map(Product.make(name:yaml:)).indexed(\.name),
      releases: yaml.releases.map(Release.make(branch:yaml:)).indexed(\.branch),
      accessories: yaml.accessories.map(Accessory.make(branch:yaml:)).indexed(\.branch)
    )}
  }
  public struct Family {
    public var name: String
    public var nextBuild: AlphaNumeric
    public var builds: [AlphaNumeric: Build]
    public func build(review: UInt, commit: Git.Sha) -> Build? {
      builds.keys.sorted().reversed().lazy.compactMap({ builds[$0] }).first(where: {
        $0.review == review && $0.commit == commit
      })
    }
    public func build(commit: Git.Sha, branch: Git.Branch) -> Build? {
      builds.keys.sorted().reversed().lazy.compactMap({ builds[$0] }).first(where: {
        $0.commit == commit && $0.branch == branch
      })
    }
    public mutating func bump(build: String) throws {
      let build = build.alphaNumeric
      guard build > nextBuild else {
        throw Thrown("Generated build \(build.value) must be greater than \(nextBuild.value)")
      }
      nextBuild = build
    }
    public static func make(
      name: String,
      yaml: Yaml.Flow.Storage.Family
    ) throws -> Self { try .init(
      name: name,
      nextBuild: yaml.nextBuild.alphaNumeric,
      builds: yaml.prevBuilds.get([:]).map(Build.make(number:yaml:)).indexed(\.number)
    )}
  }
  public struct Build {
    public var number: AlphaNumeric
    public var review: UInt?
    public var commit: Git.Sha
    public var branch: Git.Branch
    public static func make(
      number: AlphaNumeric,
      review: UInt?,
      commit: Git.Sha,
      branch: Git.Branch
    ) -> Self { .init(
      number: number,
      review: review,
      commit: commit,
      branch: branch
    )}
    public static func make(
      number: String,
      yaml: Yaml.Flow.Storage.Build
    ) throws -> Self { try .init(
      number: number.alphaNumeric,
      review: yaml.review,
      commit: .make(value: yaml.commit),
      branch: .make(name: yaml.branch)
    )}
  }
  public struct Product {
    public var name: String
    public var family: String
    public var nextVersion: AlphaNumeric
    public var prevVersions: Set<AlphaNumeric>
    public mutating func bump(version: String) throws {
      let version = version.alphaNumeric
      guard version > nextVersion else { throw Thrown(
        "Generated version \(version.value) must be greater than \(nextVersion.value)"
      )}
      prevVersions.insert(nextVersion)
      nextVersion = version
    }
    public static func make(
      name: String,
      yaml: Yaml.Flow.Storage.Product
    ) throws -> Self { .init(
      name: name,
      family: yaml.family,
      nextVersion: yaml.nextVersion.alphaNumeric,
      prevVersions: Set(yaml.prevVersions.get([]).map(\.alphaNumeric))
    )}
  }
  public struct Release {
    public var branch: Git.Branch
    public var product: String
    public var version: AlphaNumeric
    public var start: Git.Sha
    public func include(deploy: Deploy) -> Bool {
      product == deploy.product && version >= deploy.version
    }
    public static func make(
      product: Product,
      version: AlphaNumeric,
      commit: Git.Sha,
      branch: String
    ) throws -> Self { try .init(
      branch: .make(name: branch),
      product: product.name,
      version: version,
      start: commit
    )}
    public static func make(
      branch: String,
      yaml: Yaml.Flow.Storage.Release
    ) throws -> Self { try .init(
      branch: .make(name: branch),
      product: yaml.product,
      version: yaml.version.alphaNumeric,
      start: .make(value: yaml.commit)
    )}
    public enum Kind: String, Encodable {
      case release
      case hotfix
    }
  }
  public struct Stage {
    public var tag: Git.Tag
    public var product: String
    public var version: AlphaNumeric
    public var build: AlphaNumeric
    public var review: UInt?
    public var branch: Git.Branch
    public static func make(
      tag: String,
      product: Product,
      version: AlphaNumeric,
      build: AlphaNumeric,
      review: UInt?,
      branch: Git.Branch
    ) throws -> Self { try .init(
      tag: .make(name: tag),
      product: product.name,
      version: version,
      build: build,
      review: review,
      branch: branch
    )}
    public static func make(
      tag: String,
      yaml: Yaml.Flow.Storage.Stage
    ) throws -> Self { try .init(
      tag: .make(name: tag),
      product: yaml.product,
      version: yaml.version.alphaNumeric,
      build: yaml.build.alphaNumeric,
      review: yaml.review,
      branch: .make(name: yaml.branch)
    )}
  }
  public struct Deploy {
    public var tag: Git.Tag
    public var product: String
    public var version: AlphaNumeric
    public var build: AlphaNumeric
    public func include(deploy: Deploy) -> Bool {
      tag != deploy.tag && product == deploy.product && version >= deploy.version
    }
    public static func make(
      release: Release,
      build: AlphaNumeric,
      tag: String
    ) throws -> Self { try .init(
      tag: .make(name: tag),
      product: release.product,
      version: release.version,
      build: build
    )}
    public static func make(
      tag: String,
      yaml: Yaml.Flow.Storage.Deploy
    ) throws -> Self { try .init(
      tag: .make(name: tag),
      product: yaml.product,
      version: yaml.version.alphaNumeric,
      build: yaml.build.alphaNumeric
    )}
  }
  public struct Accessory {
    public var branch: Git.Branch
    public var versions: [String: AlphaNumeric]
    public static func make(branch: String) throws -> Self { try .init(
      branch: .make(name: branch),
      versions: [:]
    )}
    public static func make(
      branch: String,
      yaml: [String: String]?
    ) throws -> Self { try .init(
      branch: .make(name: branch),
      versions: yaml.get([:]).mapValues(\.alphaNumeric)
    )}
  }
  public struct ReleaseNotes: Encodable {
    public var uniq: [Note]?
    public var lack: [Note]?
    public var isEmpty: Bool { return uniq == nil && lack == nil }
    public static func make(uniq: [Note], lack: [Note]) -> Self { .init(
      uniq: uniq.isEmpty.else(uniq),
      lack: lack.isEmpty.else(lack)
    )}
    public struct Note: Encodable {
      public var sha: String
      public var msg: String
      public static func make(
        sha: Git.Sha,
        msg: String
      ) -> Self { .init(
        sha: sha.value,
        msg: msg
      )}
    }
  }
}
