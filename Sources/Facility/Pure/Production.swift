import Foundation
import Facility
public struct Production {
  public var builds: Configuration.Asset
  public var versions: Configuration.Asset
  public var accessories: Configuration.Asset
  public var buildsCount: Int
  public var releasesCount: Int
  public var createBuild: Configuration.Template
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
    accessories: .make(yaml: yaml.accessories),
    buildsCount: yaml.buildsCount,
    releasesCount: yaml.releasesCount,
    createBuild: .make(yaml: yaml.createBuild),
    exportBuilds: .make(yaml: yaml.exportBuilds),
    exportVersions: .make(yaml: yaml.exportVersions),
    matchReleaseNote: .init(yaml: yaml.matchReleaseNote),
    matchAccessoryBranch: .init(yaml: yaml.matchAccessoryBranch),
    products: yaml.products
      .map(Product.make(name:yaml:))
      .reduce(into: [:], { $0[$1.name] = $1 })
  )}
  public func productMatching(deploy: String) throws -> Product {
    let products = products.values.filter({ $0.matchDeployTagName.isMet(deploy) })
    guard products.count < 2 else { throw Thrown("Tag \(deploy) matches multiple products") }
    return try products.first.get { throw Thrown("Tag \(deploy) matches no products") }
  }
  public func makeNote(sha: String, msg: String) -> ReleaseNotes.Note? {
    guard msg.isMet(criteria: matchReleaseNote) else { return nil }
    return .init(sha: sha, msg: msg)
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
    public var createReleaseThread: Configuration.Template
    public var createReleaseVersion: Configuration.Template
    public var createReleaseBranchName: Configuration.Template
    public var matchReleaseBranch: Criteria
    public var parseReleaseBranchVersion: Configuration.Template
    public var createDeployTagName: Configuration.Template
    public var createDeployTagAnnotation: Configuration.Template
    public var matchDeployTagName: Criteria
    public var parseDeployTagBuild: Configuration.Template
    public var parseDeployTagVersion: Configuration.Template
    public static func make(
      name: String,
      yaml: Yaml.Production.Product
    ) throws -> Self { try .init(
      name: name,
      createReleaseThread: .make(yaml: yaml.createReleaseThread),
      createReleaseVersion: .make(yaml: yaml.createReleaseVersion),
      createReleaseBranchName: .make(yaml: yaml.createReleaseBranchName),
      matchReleaseBranch: .init(yaml: yaml.matchReleaseBranch),
      parseReleaseBranchVersion: .make(yaml: yaml.parseReleaseBranchVersion),
      createDeployTagName: .make(yaml: yaml.createDeployTagName),
      createDeployTagAnnotation: .make(yaml: yaml.createDeployTagAnnotation),
      matchDeployTagName: .init(yaml: yaml.matchDeployTagName),
      parseDeployTagBuild: .make(yaml: yaml.parseDeployTagBuild),
      parseDeployTagVersion: .make(yaml: yaml.parseDeployTagVersion)
    )}
    public func deploy(build: String, sha: String, tag: String) -> Build.Tag {
      .init(build: build, sha: sha, tag: tag)
    }
  }
  public enum Build {
    case tag(Tag)
    case branch(Branch)
    case review(Review)
    public var yaml: String {
      switch self {
      case .tag(let tag): return tag.yaml.joined()
      case .branch(let branch): return branch.yaml.joined()
      case .review(let review): return review.yaml.joined()
      }
    }
    public var build: String {
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
    public static func make(build: String, yaml: Yaml.Production.Build) throws -> Self {
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
      public static func make(
        build: String,
        sha: String,
        branch: String
      ) -> Self { .init(
        build: build,
        sha: sha,
        branch: branch
      )}
    }
    public struct Tag: Encodable {
      public var build: String
      public var sha: String
      public var tag: String
      public var yaml: [String] { [
        "- build: '\(build)'\n",
        "  sha: '\(sha)'\n",
        "  tag: \(tag)\n"
      ]}
      public static func make(
        build: String,
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
    public internal(set) var next: String
    public internal(set) var flow: [[String]]
    public internal(set) var deliveries: [String: Delivery]
    public static func make(
      product: String,
      yaml: Yaml.Production.Version
    ) throws -> Self { try .init(
      product: product,
      next: yaml.next,
      flow: yaml.flow.get([]),
      deliveries: yaml.deliveries
        .get([:])
        .map(Delivery.make(version:yaml:))
        .reduce(into: [:], { $0[$1.version] = $1 })
    )}
    public mutating func release(
      next version: String,
      start: Git.Sha,
      branch: Git.Branch,
      thread: Yaml.Thread
    ) -> Delivery {
      var result = Delivery(
        version: next,
        thread: .make(yaml: thread),
        deploys: [start]
      )
      let previous = deliveries.values
        .reduce(into: Set(), { $0.formUnion($1.deploys) })
      flow.append([next])
      deliveries[next] = result
      next = version
      result.deploys = previous
      return result
    }
    public mutating func hotfix(
      from previous: String,
      version: String,
      start: Git.Sha,
      thread: Yaml.Thread
    ) throws -> Delivery {
      guard let index = flow.firstIndex(where: { $0.last == previous })
      else { throw Thrown("Unable to hotfix \(product) \(version)") }
      var result = Delivery(
        version: next,
        thread: .make(yaml: thread),
        deploys: [start]
      )
      let previous = (0 ... index)
        .flatMap({ flow[$0] })
        .compactMap({ deliveries[$0]?.deploys })
        .reduce(into: Set(), { $0.formUnion($1) })
      flow[index].append(version)
      deliveries[version] = result
      result.deploys = previous
      return result
    }
    public mutating func deploy(
      version: String,
      sha: Git.Sha
    ) throws {
      guard deliveries[version] != nil else { throw Thrown("No delivery \(product) \(version)") }
      deliveries[version]?.deploys.insert(sha)
    }
    public static func serialize(versions: [String: Self]) -> String {
      guard versions.isEmpty.not else { return "{}\n" }
      var result: String = ""
      for version in versions.keys.sorted().compactMap({ versions[$0] }) {
        result += "'\(version.product)':\n"
        result += "  next: '\(version.next)'\n"
        let flow = version.flow.filter(\.isEmpty.not)
        if flow.isEmpty.not {
          result += "  flow:\n"
          result += flow.map({ "  - ['\($0.joined(separator: "','"))']\n" }).joined()
          result += "  deliveries:\n"
          for delivery in flow.flatMap({ $0 }).sorted().compactMap({ version.deliveries[$0] }) {
            result += "    '\(delivery.version)':\n"
            result += "      thread: \(delivery.thread.serialize())\n"
            if delivery.deploys.isEmpty.not {
              result += "      deploys:\n"
              result += delivery.deploys.map({ "      - '\($0.value)'\n" }).sorted().joined()
            }
          }
        }
      }
      return result
    }
    public struct Delivery {
      public var version: String
      public var thread: Configuration.Thread
      public var deploys: Set<Git.Sha>
      public static func make(
        version: String,
        yaml: Yaml.Production.Version.Delivery
      ) throws -> Self { try .init(
        version: version,
        thread: .make(yaml: yaml.thread),
        deploys: Set(yaml.deploys
          .get([])
          .map(Git.Sha.make(value:))
        )
      )}
    }
  }
}
