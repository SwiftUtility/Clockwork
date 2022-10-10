import Foundation
import Facility
public struct Production {
  public var builds: Configuration.Asset
  public var versions: Configuration.Asset
  public var buildsCount: Int
  public var releasesCount: Int
  public var bumpBuildNumber: Configuration.Template
  public var exportBuilds: Configuration.Template
  public var exportVersions: Configuration.Template
  public var matchReleaseNote: Criteria
  public var matchAccessoryBranch: Criteria
  public var products: [String: Product]
  public static func make(
    yaml: Yaml.Production
  ) throws -> Self { try .init(
    builds: .make(yaml: yaml.builds),
    versions: .make(yaml: yaml.versions),
    buildsCount: yaml.buildsCount,
    releasesCount: yaml.releasesCount,
    bumpBuildNumber: .make(yaml: yaml.bumpBuildNumber),
    exportBuilds: .make(yaml: yaml.exportBuilds),
    exportVersions: .make(yaml: yaml.exportVersions),
    matchReleaseNote: .init(yaml: yaml.matchReleaseNote),
    matchAccessoryBranch: .init(yaml: yaml.matchAccessoryBranch),
    products: yaml.products
      .map(Product.make(name:yaml:))
      .reduce(into: [:], { $0[$1.name] = $1 })
  )}
  public func productMatching(deploy: String) throws -> Product? {
    let products = products.values.filter({ $0.matchDeployTag.isMet(deploy) })
    guard products.count < 2 else { throw Thrown("Tag \(deploy) matches multiple products") }
    return products.first
  }
  public func productMatching(stage: String) throws -> Product? {
    let products = products.values.filter({ $0.matchStageTag.isMet(stage) })
    guard products.count < 2 else { throw Thrown("Tag \(stage) matches multiple products") }
    return products.first
  }
  public func productMatching(release: String) throws -> Product? {
    let products = products.values.filter({ $0.matchReleaseBranch.isMet(release) })
    guard products.count < 2 else { throw Thrown("Branch \(release) matches multiple products") }
    return products.first
  }
  public func makeNote(sha: String, msg: String) -> ReleaseNotes.Note? {
    guard msg.isMet(criteria: matchReleaseNote) else { return nil }
    return .init(sha: sha, msg: msg)
  }
  public func serialize(builds: [AlphaNumeric: Build]) -> String {
    let builds = builds.keys
      .sorted()
      .compactMap({ builds[$0] })
      .suffix(buildsCount)
    guard builds.isEmpty.not else { return "{}\n" }
    var result: String = ""
    for build in builds {
      switch build {
      case .tag(let tag): result += tag.yaml.joined()
      case .branch(let branch): result += branch.yaml.joined()
      case .review(let review): result += review.yaml.joined()
      }
    }
    return result
  }
  public func serialize(versions: [String: Version]) -> String {
    guard versions.isEmpty.not else { return "{}\n" }
    var result: String = ""
    for version in versions.keys.sorted().compactMap({ versions[$0] }) {
      result += "'\(version.product)':\n"
      result += "  next: '\(version.next)'\n"
      let deliveries = version.deliveries.keys
        .sorted()
        .compactMap({ version.deliveries[$0] })
        .suffix(releasesCount)
      if deliveries.isEmpty.not {
        result += "  deliveries:\n"
        for delivery in deliveries {
          result += "    '\(delivery.version)':\n"
          result += "      thread: \(delivery.thread.serialize())\n"
          if delivery.deploys.isEmpty.not {
            result += "      deploys:\n"
            result += delivery.deploys.map({ "      - '\($0.value)'\n" }).sorted().joined()
          }
        }
      }
      if version.accessories.isEmpty.not {
        result += "  accessories:\n"
        result += version.accessories.keys
          .sorted()
          .compactMap({ try? "    '\($0)': '\(?!version.accessories[$0])'\n" })
          .joined()
      }
    }
    return result
  }
  public struct ReleaseNotes: Encodable {
    public var uniq: [Note]?
    public var lack: [Note]?
    public var isEmpty: Bool { return uniq == nil && lack == nil }
    public static func make(uniq: [Note], lack: [Note]) -> Self {
      return .init(uniq: uniq.isEmpty.else(uniq), lack: lack.isEmpty.else(lack))
    }
    public struct Note: Encodable {
      public var sha: String
      public var msg: String
    }
  }
  public struct Product {
    public var name: String
    public var matchStageTag: Criteria
    public var matchDeployTag: Criteria
    public var matchReleaseBranch: Criteria
    public var parseTagBuild: Configuration.Template
    public var parseTagVersion: Configuration.Template
    public var parseBranchVersion: Configuration.Template
    public var bumpReleaseVersion: Configuration.Template
    public var createTagName: Configuration.Template
    public var createTagAnnotation: Configuration.Template
    public var createReleaseThread: Configuration.Template
    public var createReleaseBranchName: Configuration.Template
    public static func make(
      name: String,
      yaml: Yaml.Production.Product
    ) throws -> Self { try .init(
      name: name,
      matchStageTag: .init(yaml: yaml.matchStageTag),
      matchDeployTag: .init(yaml: yaml.matchDeployTag),
      matchReleaseBranch: .init(yaml: yaml.matchReleaseBranch),
      parseTagBuild: .make(yaml: yaml.parseTagBuild),
      parseTagVersion: .make(yaml: yaml.parseTagVersion),
      parseBranchVersion: .make(yaml: yaml.parseBranchVersion),
      bumpReleaseVersion: .make(yaml: yaml.bumpReleaseVersion),
      createTagName: .make(yaml: yaml.createTagName),
      createTagAnnotation: .make(yaml: yaml.createTagAnnotation),
      createReleaseThread: .make(yaml: yaml.createReleaseThread),
      createReleaseBranchName: .make(yaml: yaml.createReleaseBranchName)
    )}
    public func deploy(build: AlphaNumeric, sha: String, tag: String) -> Build.Tag {
      .init(build: build, sha: sha, tag: tag)
    }
  }
  public enum Build {
    case tag(Tag)
    case branch(Branch)
    case review(Review)
    public var build: AlphaNumeric {
      switch self {
      case .tag(let tag): return tag.build
      case .branch(let branch): return branch.build
      case .review(let review): return review.build
      }
    }
    public var review: String? {
      guard case .review(let review) = self else { return nil }
      return "\(review.review)"
    }
    public var target: String? {
      guard case .review(let review) = self else { return nil }
      return review.target
    }
    public var branch: String? {
      guard case .branch(let branch) = self else { return nil }
      return "\(branch.branch)"
    }
    public var tag: String? {
      guard case .tag(let tag) = self else { return nil }
      return "\(tag.tag)"
    }
    public var sha: String {
      switch self {
      case .tag(let tag): return tag.sha
      case .branch(let branch): return branch.sha
      case .review(let review): return review.sha
      }
    }
    public static func make(build: AlphaNumeric, yaml: Yaml.Production.Build) throws -> Self {
      switch (yaml.review, yaml.target, yaml.branch, yaml.tag) {
      case (nil, nil, nil, let tag?): return .tag(.make(
        build: build,
        sha: yaml.sha,
        tag: tag
      ))
      case (nil, nil, let branch?, nil): return .branch(.make(
        build: build,
        sha: yaml.sha,
        branch: branch
      ))
      case (let review?, let target?, nil, nil): return .review(.make(
        build: build,
        sha: yaml.sha,
        review: review,
        target: target
      ))
      default: throw Thrown("Wrong build format")
      }
    }
    public struct Review: Encodable {
      public var build: AlphaNumeric
      public var sha: String
      public var review: UInt
      public var target: String
      public var yaml: [String] { [
        "'\(build)':\n",
        "  sha: '\(sha)'\n",
        "  review: \(review)\n",
        "  target: \(target)\n",
      ]}
      public static func make(
        build: AlphaNumeric,
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
      public var build: AlphaNumeric
      public var sha: String
      public var branch: String
      public var yaml: [String] { [
        "'\(build)':\n",
        "  sha: '\(sha)'\n",
        "  branch: \(branch)\n",
      ]}
      public static func make(
        build: AlphaNumeric,
        sha: String,
        branch: String
      ) -> Self { .init(
        build: build,
        sha: sha,
        branch: branch
      )}
    }
    public struct Tag: Encodable {
      public var build: AlphaNumeric
      public var sha: String
      public var tag: String
      public var yaml: [String] { [
        "'\(build)':\n",
        "  sha: '\(sha)'\n",
        "  tag: \(tag)\n"
      ]}
      public static func make(
        build: AlphaNumeric,
        sha: String,
        tag: String
      ) -> Self { .init(
        build: build,
        sha: sha,
        tag: tag
      )}
    }
  }
  public struct Version {
    public internal(set) var product: String
    public internal(set) var next: AlphaNumeric
    public internal(set) var deliveries: [AlphaNumeric: Delivery]
    public internal(set) var accessories: [String: AlphaNumeric]
    public static func make(
      product: String,
      yaml: Yaml.Production.Version
    ) throws -> Self { try .init(
      product: product,
      next: yaml.next,
      deliveries: yaml.deliveries.get([:])
        .map(Delivery.make(version:yaml:))
        .reduce(into: [:], { $0[$1.version] = $1 }),
      accessories: yaml.accessories.get([:])
    )}
    public func check(bump: String) throws {
      let bump = bump.alphaNumeric
      guard deliveries[next] == nil
      else { throw Thrown("\(product) \(next) already exists") }
      guard deliveries[bump] == nil
      else { throw Thrown("\(product) \(bump) already exists") }
      guard bump > next
      else { throw Thrown("\(product) \(bump) is not after \(next)") }
    }
    public mutating func release(
      bump: String,
      start: Git.Sha,
      thread: Yaml.Thread
    ) -> Delivery {
      let result = Delivery(
        version: next,
        thread: .make(yaml: thread),
        deploys: [start],
        previous: deliveries.keys
          .sorted()
          .compactMap({ deliveries[$0] })
          .prefix(while: { $0.version < next })
          .reduce(into: [], { $0.formUnion($1.deploys) })
      )
      deliveries[next] = result
      next = .make(bump)
      return result
    }
    public func check(hotfix: String, of previous: String) throws {
      let previous = previous.alphaNumeric
      let hotfix = hotfix.alphaNumeric
      guard deliveries[previous] != nil
      else { throw Thrown("No \(product) \(previous) ") }
      guard deliveries[hotfix] == nil
      else { throw Thrown("\(product) \(previous) already exists") }
      guard !deliveries.values.contains(where: { $0.version > previous && $0.version < hotfix })
      else { throw Thrown("\(product) \(hotfix) is not the latest hotfix") }
    }
    public mutating func hotfix(
      version: String,
      start: Git.Sha,
      thread: Yaml.Thread
    ) -> Delivery {
      let version = version.alphaNumeric
      let result = Delivery(
        version: version,
        thread: .make(yaml: thread),
        deploys: [start],
        previous: deliveries.keys
          .sorted()
          .compactMap({ deliveries[$0] })
          .prefix(while: { $0.version < version })
          .reduce(into: [], { $0.formUnion($1.deploys) })
      )
      deliveries[version] = result
      return result
    }
    public mutating func deploy(
      version: String,
      sha: Git.Sha
    ) throws -> Delivery {
      let version = version.alphaNumeric
      guard var delivery = deliveries[version] else { throw Thrown("No \(product) \(version)") }
      let delpoys = deliveries.values
        .filter({ $0.version < version })
        .reduce(into: delivery.deploys, { $0.formUnion($1.deploys) })
      deliveries[version]?.deploys.insert(sha)
      delivery.deploys.formUnion(delpoys)
      return delivery
    }
    public struct Delivery {
      public var version: AlphaNumeric
      public var thread: Configuration.Thread
      public var deploys: Set<Git.Sha>
      public var previous: Set<Git.Sha>
      public static func make(
        version: AlphaNumeric,
        yaml: Yaml.Production.Version.Delivery
      ) throws -> Self { try .init(
        version: version,
        thread: .make(yaml: yaml.thread),
        deploys: Set(yaml.deploys
          .get([])
          .map(Git.Sha.make(value:))
        ),
        previous: []
      )}
    }
  }
}
