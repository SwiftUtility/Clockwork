import Foundation
import Facility
public struct Production {
  public var builds: Configuration.Asset
  public var buildsCount: Int
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
    buildsCount: yaml.buildsCount,
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
    let products = products.values.filter({ $0.deploy.matchName.isMet(deploy) })
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
    public var stage: Tag
    public var deploy: Tag
    public var hotfix: Branch
    public var release: Branch
    public var versions: Configuration.Asset
    public static func make(
      name: String,
      yaml: Yaml.Production.Product
    ) throws -> Self { try .init(
      name: name,
      stage: .make(yaml: yaml.stage),
      deploy: .make(yaml: yaml.deploy),
      hotfix: .make(yaml: yaml.hotfix),
      release: .make(yaml: yaml.release),
      versions: .make(yaml: yaml.versions)
    )}
    public struct Tag {
      public var matchName: Criteria
      public var parseBuild: Configuration.Template
      public var parseVersion: Configuration.Template
      public var createName: Configuration.Template
      public var createAnnotation: Configuration.Template
      public static func make(yaml: Yaml.Production.Product.Tag) throws -> Self { try .init(
        matchName: .init(yaml: yaml.matchName),
        parseBuild: .make(yaml: yaml.parseBuild),
        parseVersion: .make(yaml: yaml.parseVersion),
        createName: .make(yaml: yaml.createName),
        createAnnotation: .make(yaml: yaml.createAnnotation)
      )}
    }
    public struct Branch {
      public var createName: Configuration.Template
      public var createThread: Configuration.Template
      public var createVersion: Configuration.Template
      public static func make(yaml: Yaml.Production.Product.Branch) throws -> Self { try .init(
        createName: .make(yaml: yaml.createName),
        createThread: .make(yaml: yaml.createThread),
        createVersion: .make(yaml: yaml.createVersion)
      )}
    }
    public func deploy(build: String, sha: String, tag: String) -> Build.Tag {
      .init(build: build, sha: sha, tag: tag)
    }
  }
  public struct DeployTag {
    public var createName: Configuration.Template
    public var createAnnotation: Configuration.Template
    public var parseBuild: Configuration.Template
    public var parseVersion: Configuration.Template
    public var parseProduct: Configuration.Template
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
    public var target: String? {
      guard case .review(let review) = self else { return nil }
      return review.target
    }
    public static func make(yaml: Yaml.Production.Build) throws -> Self {
      switch (yaml.review, yaml.target, yaml.branch, yaml.tag) {
      case (nil, nil, nil, let tag?): return .tag(.make(
        build: yaml.build,
        sha: yaml.sha,
        tag: tag
      ))
      case (nil, nil, let branch?, nil): return .branch(.make(
        build: yaml.build,
        sha: yaml.sha,
        branch: branch
      ))
      case (let review?, let target?, nil, nil): return .review(.make(
        build: yaml.build,
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
  public struct Versions {
    public internal(set) var next: String
    public internal(set) var flow: [[String]]
    public internal(set) var deliveries: [String: Delivery]
    public internal(set) var accessories: [String: String]
    public static func make(yaml: Yaml.Production.Versions) throws -> Self { try .init(
      next: yaml.next,
      flow: yaml.flow.get([]),
      deliveries: yaml.deliveries
        .get([:])
        .map(Delivery.make(version:yaml:))
        .reduce(into: [:], { $0[$1.version] = $1 }),
      accessories: yaml.accessories.get([:])
    )}
    public mutating func release(
      next version: String,
      start: Git.Sha,
      branch: Git.Branch,
      thread: Yaml.Thread
    ) -> Delivery {
      var result = Delivery(
        branch: branch,
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
      branch: Git.Branch,
      thread: Yaml.Thread
    ) throws -> Delivery {
      guard let index = flow.firstIndex(where: { $0.last == previous })
      else { throw Thrown("Unable to hotfix \(version)") }
      var result = Delivery(
        branch: branch,
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
      guard deliveries[version] != nil else { throw Thrown("No delivery \(version)") }
      deliveries[version]?.deploys.insert(sha)
    }
    public func serialize() -> String {
      var result: String = ""
      result += "next: '\(next)'\n"
      let flow = flow.filter(\.isEmpty.not)
      if flow.isEmpty.not {
        result += "flow:\n"
        result += flow.map({ "- ['\($0.joined(separator: "','"))']\n" }).joined()
      }
      result += "deliveries:\n"
      for delivery in flow.flatMap({ $0 }).sorted().compactMap({ deliveries[$0] }) {
        result += "  '\(delivery.version)':\n"
        result += "    branch: '\(delivery.branch.name)'\n"
        result += "    thread: \(delivery.thread.serialize())\n"
        if delivery.deploys.isEmpty.not {
          result += "    deploys:\n"
          result += delivery.deploys.map({ "    - '\($0.value)'\n" }).sorted().joined()
        }
      }
      return result
    }
    public struct Delivery {
      public var branch: Git.Branch
      public var version: String
      public var thread: Configuration.Thread
      public var deploys: Set<Git.Sha>
      public static func make(
        version: String,
        yaml: Yaml.Production.Versions.Delivery
      ) throws -> Self { try .init(
        branch: .init(name: yaml.branch),
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
