import Foundation
import Facility
public struct Flow {
  public var builds: Builds?
  public var versions: Versions
  public var matchReleaseNote: Criteria
  public var exportVersions: Configuration.Template
  public var createTagName: Configuration.Template
  public var createTagAnnotation: Configuration.Template
  public var createReleaseBranchName: Configuration.Template
  public static func make(
    yaml: Yaml.Flow
  ) throws -> Self { try .init(
    builds: yaml.builds.map(Builds.make(yaml:)),
    versions: .make(yaml: yaml.versions),
    matchReleaseNote: .init(yaml: yaml.matchReleaseNote),
    exportVersions: .make(yaml: yaml.exportVersions),
    createTagName: .make(yaml: yaml.createTagName),
    createTagAnnotation: .make(yaml: yaml.createTagAnnotation),
    createReleaseBranchName: .make(yaml: yaml.createReleaseBranchName)
  )}
  public func makeNote(sha: String, msg: String) -> ReleaseNotes.Note? {
    guard msg.isMet(criteria: matchReleaseNote) else { return nil }
    return .init(sha: sha, msg: msg)
  }
  public struct Builds {
    public var storage: Configuration.Asset
    public var maxBuildsCount: Int
    public var bump: Configuration.Template
    public static func make(yaml: Yaml.Flow.Builds) throws -> Self { try .init(
      storage: .make(yaml: yaml.storage),
      maxBuildsCount: yaml.maxBuildsCount,
      bump: .make(yaml: yaml.bump)
    )}
    public struct Storage {
      public var next: AlphaNumeric
      public var reserved: [AlphaNumeric: Build]
      public var recent: [Build] { reserved.keys
        .sorted()
        .reversed()
        .compactMap({ reserved[$0] })
      }
      public mutating func reserve(
        tag: Git.Tag,
        sha: Git.Sha,
        bump: String
      ) throws -> Build { try reserve(
        bump: bump.alphaNumeric,
        build: .init(number: next, commit: sha, tag: tag)
      )}
      public mutating func reserve(
        review: Json.GitlabReviewState,
        job: Json.GitlabJob,
        bump: String
      ) throws -> Build { try reserve(
        bump: bump.alphaNumeric,
        build: .init(
          number: next,
          commit: .make(job: job),
          review: review.iid,
          target: .make(name: review.targetBranch)
        )
      )}
      public mutating func reserve(
        branch: Git.Branch,
        sha: Git.Sha,
        bump: String
      ) throws -> Build { try reserve(
        bump: bump.alphaNumeric,
        build: .init(number: next, commit: sha, branch: branch)
      )}
      mutating func reserve(bump: AlphaNumeric, build: Build) throws -> Build {
        guard bump > next else { throw Thrown("Bump is not the latest") }
        guard reserved.keys.contains(where: { $0 >= next }).not
        else { throw Thrown("Next build is not the latest") }
        reserved[next] = build
        next = bump
        return build
      }
      public func serialized(builds: Builds) -> String {
        var result: String = ""
        result += "next: '\(next.value)'\n"
        if reserved.isEmpty.not {
          result += "reserved:\n"
          for build in reserved.keys
            .sorted()
            .compactMap({ reserved[$0] })
            .suffix(builds.maxBuildsCount)
          {
            result += "  '\(build.number.value)':\n"
            result += "    commit: '\(build.commit.value)'\n"
            result += build.tag.map({ "    tag: '\($0)'\n" }).get("")
            result += build.branch.map({ "    branch: '\($0)'\n" }).get("")
            result += build.review.map({ "    review: \($0)\n" }).get("")
            result += build.target.map({ "    target: '\($0)'\n" }).get("")
          }
        }
        return result
      }
      public static func make(yaml: Yaml.Flow.Builds.Storage) throws -> Self { try .init(
        next: yaml.next.alphaNumeric,
        reserved: yaml.reserved
          .get([:])
          .map(Build.make(build:yaml:))
          .reduce(into: [:], { $0[$1.number] = $1 })
      )}
    }
  }
  public struct Versions {
    public var storage: Configuration.Asset
    public var maxReleasesCount: Int
    public var bump: Configuration.Template
    public static func make(yaml: Yaml.Flow.Versions) throws -> Self { try .init(
      storage: .make(yaml: yaml.storage),
      maxReleasesCount: yaml.maxReleasesCount,
      bump: .make(yaml: yaml.bump)
    )}
    public struct Storage {
      public var products: [String: Product]
      public var accessories: [Git.Branch: Accessory]
      public func serialized(versions: Versions) -> String {
        var result: String = ""
        if products.isEmpty.not { result += "products:\n" }
        for product in products.keys.sorted().compactMap({ products[$0] }) {
          result += "  '\(product.name)':\n"
          result += "    next: '\(product.next.value)'\n"
          if product.stages.isEmpty.not { result += "    stages:\n" }
          for stage in product.stages.keys.sorted().compactMap({ product.stages[$0] }) {
            result += "      '\(stage.tag.name)':\n"
            result += "        version: '\(stage.version.value)'\n"
            result += "        build: '\(stage.build.value)'\n"
            if let review = stage.review {
              result += "        review: \(review)\n"
            }
            if let target = stage.target {
              result += "        target: '\(target.name)'\n"
            }
            if let branch = stage.branch {
              result += "        branch: '\(branch.name)'\n"
            }
          }
          if product.releases.isEmpty.not { result += "    releases:\n" }
          for release in product.releases.keys
            .sorted()
            .compactMap({ product.releases[$0] })
            .suffix(versions.maxReleasesCount)
          {
            result += "      '\(release.version.value)':\n"
            result += "        start: '\(release.start.value)'\n"
            result += "        branch: '\(release.branch.name)'\n"
            if release.deploys.isEmpty.not {
              result += "        deploys:\n"
            }
            for deploy in release.deploys.sorted() {
              result += "        - '\(deploy.name)'\n"
            }
          }
        }
        if accessories.isEmpty.not { result += "accessories:\n" }
        for accessory in accessories.keys.sorted().compactMap({ accessories[$0] }) {
          if accessory.versions.isEmpty {
            result += "  '\(accessory.branch.name)': {}\n"
          } else {
            result += "  '\(accessory.branch.name)':\n"
            result += "    versions:\n"
          }
          for version in accessory.versions.keys.sorted().compactMap({ accessory.versions[$0] }) {
            result += "      '\(version.product)': '\(version.version.value)'\n"
          }
        }
        return result
      }
      public var versions: [String: String] {
        products.mapValues(\.next.value)
      }
      public func versions(stage: Product.Stage) -> [String: String] {
        [stage].reduce(into: versions, { $0[$1.product] = $1.version.value })
      }
      public func versions(release: Product.Release) -> [String: String] {
        [release].reduce(into: versions, { $0[$1.product] = $1.version.value })
      }
      public func versions(build: Build) -> [String: String] {
        if let release = build.tag.flatMap(find(deploy:)) { return versions(release: release) }
        let branch = build.branch.flatMapNil(build.target)
        if let release = branch.flatMap(find(release:)) { return versions(release: release) }
        return branch.flatMap({ accessories[$0]?.versions }).get([:]).values
          .reduce(into: versions, { $0[$1.product] = $1.version.value })
      }
      public mutating func change(product: String, next bump: String) throws {
        guard var product = products[product]
        else { throw Thrown("Not configured product: \(product)") }
        let bump = bump.alphaNumeric
        guard product.next != bump
        else { throw Thrown("\(product.name) nextVersion is already \(bump)") }
        guard product.releases.map(\.value.version).filter({ $0 >= bump }).isEmpty
        else { throw Thrown("\(product.name) \(bump) is not the latest") }
        product.next = bump
        products[product.name] = product
      }
      public mutating func change(accessory: String, product: String, version: String) throws {
        guard products[product] != nil
        else { throw Thrown("Not configured product: \(product)") }
        guard var accessory = try accessories[.make(name: accessory)]
        else { throw Thrown("Not configured accessory: \(accessory)") }
        accessory.versions[product] = .make(product: product, version: version)
        accessories[accessory.branch] = accessory
      }
      public mutating func create(accessory branch: String) throws -> Accessory {
        let branch = try Git.Branch.make(name: branch)
        guard accessories[branch] == nil
        else { throw Thrown("Already exists \(branch.name)") }
        let accessory = Accessory(branch: branch, versions: [:])
        accessories[branch] = accessory
        return accessory
      }
      public mutating func delete(stage: Git.Tag) throws -> Product.Stage {
        for var product in products.values {
          guard let stage = product.stages[stage] else { continue }
          product.stages[stage.tag] = nil
          products[product.name] = product
          return stage
        }
        throw Thrown("No stage tag \(stage.name)")
      }
      public mutating func release(
        product: String,
        branch: Git.Branch,
        sha: Git.Sha,
        hotfix: Bool,
        bump: String
      ) throws -> Product.Release {
        let bump = bump.alphaNumeric
        guard var product = products[product]
        else { throw Thrown("No product \(product)") }
        guard product.releases[bump] == nil
        else { throw Thrown("Already released \(product.name) \(product.next.value)") }
        guard product.releases[product.next] == nil
        else { throw Thrown("Already released \(product.name) \(product.next.value)") }
        let version: AlphaNumeric
        if hotfix {
          guard bump < product.next
          else { throw Thrown("Hotfix \(bump.value) in not before \(product.next.value)") }
          version = bump
        } else {
          guard bump > product.next
          else { throw Thrown("Release \(bump.value) in not after \(product.next.value)") }
          version = product.next
          product.next = bump
        }
        var release = Product.Release(
          product: product.name,
          start: sha,
          branch: branch,
          version: version,
          deploys: [],
          previous: []
        )
        release.previous = product.releases.keys
          .filter({ $0 < version })
          .compactMap({ product.releases[$0]?.deploys })
          .reduce(into: release.deploys, { $0.formUnion($1) })
        product.releases[version] = release
        products[product.name] = product
        return release
      }
      public mutating func deploy(
        product: String,
        version: AlphaNumeric,
        tag: Git.Tag
      ) throws -> Product.Release {
        guard var product = products[product]
        else { throw Thrown("No product \(product)") }
        guard var release = product.releases[version]
        else { throw Thrown("No release version \(version.value)") }
        release.deploys.insert(tag)
        product.releases[release.version] = release
        products[product.name] = product
        release.previous = product.releases.keys
          .filter({ $0 < version })
          .compactMap({ product.releases[$0]?.deploys })
          .reduce(into: release.deploys, { $0.formUnion($1) })
        return release
      }
      public mutating func stage(
        product: String,
        version: AlphaNumeric?,
        build: Build,
        tag: Git.Tag
      ) throws -> Product.Stage {
        guard var product = products[product]
        else { throw Thrown("No product \(product)") }
        guard product.stages[tag] == nil
        else { throw Thrown("Alredy staged \(tag.name)") }
        let stage = Product.Stage(
          product: product.name,
          tag: tag,
          version: version.get(product.next),
          build: build.number,
          review: build.review,
          target: build.target,
          branch: build.branch
        )
        product.stages[tag] = stage
        products[product.name] = product
        return stage
      }
      public func find(
        release branch: Git.Branch
      ) -> Product.Release? { products.values
        .flatMap(\.recent)
        .first(where: { $0.branch == branch })
      }
      public func find(
        deploy tag: Git.Tag
      ) -> Product.Release? { products.values
        .flatMap(\.recent)
        .first(where: { $0.deploys.contains(tag) })
      }
      public func find(
        stage tag: Git.Tag
      ) -> Product.Stage? { products
        .values
        .compactMap({ $0.stages[tag] })
        .first
      }
      public mutating func delete(accessory branch: Git.Branch) throws -> Accessory {
        guard let accessory = accessories[branch]
        else { throw Thrown("No accessory \(branch.name)") }
        accessories[branch] = nil
        return accessory
      }
      public static func make(yaml: Yaml.Flow.Versions.Storage) throws -> Self { try .init(
        products: yaml.products
          .get([:])
          .map(Product.make(name:yaml:))
          .reduce(into: [:], { $0[$1.name] = $1 }),
        accessories: yaml.accessories
          .get([:])
          .map(Accessory.make(branch:yaml:))
          .reduce(into: [:], { $0[$1.branch] = $1 })
      )}
    }
  }
  public struct ReleaseNotes: Encodable {
    public var uniq: [Note]?
    public var lack: [Note]?
    public var uniqs: [[Note]]?
    public var lacks: [[Note]]?
    public var isEmpty: Bool { return uniq == nil && lack == nil }
    public static func make(uniq: [Note], lack: [Note]) -> Self {
      let uniqs = stride(from: 0, to: uniq.count, by: 10)
        .map({ Array(uniq.suffix(from: $0).prefix(10)) })
      let lacks = stride(from: 0, to: lack.count, by: 10)
        .map({ Array(lack.suffix(from: $0).prefix(10)) })
      return .init(
        uniq: uniq.isEmpty.else(uniq),
        lack: lack.isEmpty.else(lack),
        uniqs: uniqs.isEmpty.else(uniqs),
        lacks: lacks.isEmpty.else(lacks)
      )
    }
    public struct Note: Encodable {
      public var sha: String
      public var msg: String
    }
  }
  public struct Build {
    public var number: AlphaNumeric
    public var commit: Git.Sha
    public var tag: Git.Tag?
    public var review: UInt?
    public var target: Git.Branch?
    public var branch: Git.Branch?
    public var kind: Generate.ExportVersions.Kind? {
      if tag != nil { return .deploy }
      if branch != nil { return .branch }
      if review != nil { return .review }
      return nil
    }
    public static func make(
      build: String,
      yaml: Yaml.Flow.Builds.Storage.Build
    ) throws -> Self { try .init(
      number: build.alphaNumeric,
      commit: .make(value: yaml.commit),
      tag: yaml.tag.map(Git.Tag.make(name:)),
      review: yaml.review,
      target: yaml.target.map(Git.Branch.make(name:)),
      branch: yaml.branch.map(Git.Branch.make(name:))
    )}
  }
  public struct Accessory {
    public var branch: Git.Branch
    public var versions: [String: Version]
    public static func make(
      branch: String,
      yaml: Yaml.Flow.Versions.Storage.Accessory
    ) throws -> Self { try .init(
      branch: .make(name: branch),
      versions: yaml.versions
        .get([:])
        .map(Version.make(product:version:))
        .reduce(into: [:], { $0[$1.product] = $1 })
    )}
    public struct Version {
      public var product: String
      public var version: AlphaNumeric
      public static func make(
        product: String,
        version: String
      ) -> Self { .init(
        product: product,
        version: version.alphaNumeric
      )}
    }
  }
  public struct Product {
    public var name: String
    public var next: AlphaNumeric
    public var stages: [Git.Tag: Stage] = [:]
    public var releases: [AlphaNumeric: Release] = [:]
    public var recent: [Release] { releases.keys
      .sorted()
      .reversed()
      .compactMap({ releases[$0] })
    }
    public static func make(
      name: String,
      yaml: Yaml.Flow.Versions.Storage.Product
    ) throws -> Self {
      var result = Self(name: name, next: yaml.next.alphaNumeric)
      result.stages = try yaml.stages
        .get([:])
        .map(result.makeStage(tag:yaml:))
        .reduce(into: [:], { $0[$1.tag] = $1 })
      result.releases = try yaml.releases
        .get([:])
        .map(result.makeRelease(version:yaml:))
        .reduce(into: [:], { $0[$1.version] = $1 })
      return result
    }
    public func makeStage(
      tag: String,
      yaml: Yaml.Flow.Versions.Storage.Stage
    ) throws -> Stage { try .init(
      product: name,
      tag: .make(name: tag),
      version: yaml.version.alphaNumeric,
      build: yaml.build.alphaNumeric,
      review: yaml.review,
      target: .make(name: yaml.target),
      branch: .make(name: yaml.branch)
    )}
    public func makeRelease(
      version: String,
      yaml: Yaml.Flow.Versions.Storage.Release
    ) throws -> Release { try .init(
      product: name,
      start: .make(value: yaml.start),
      branch: .make(name: yaml.branch),
      version: version.alphaNumeric,
      deploys: Set(yaml.deploys.get([]).map(Git.Tag.make(name:))),
      previous: []
    )}
    public struct Stage {
      public var product: String
      public var tag: Git.Tag
      public var version: AlphaNumeric
      public var build: AlphaNumeric
      public var review: UInt?
      public var target: Git.Branch?
      public var branch: Git.Branch?
    }
    public struct Release {
      public var product: String
      public var start: Git.Sha
      public var branch: Git.Branch
      public var version: AlphaNumeric
      public var deploys: Set<Git.Tag>
      public var previous: Set<Git.Tag>
    }
  }
}
