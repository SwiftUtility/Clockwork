import Foundation
import Facility
public struct Production {
  public var builds: Configuration.Asset
  public var versions: Configuration.Asset
  public var generateNextBuild: Configuration.Template
  public var products: [Product]
  public var generateReleaseNotes: Configuration.Template?
  public var maxBuildsCount: Int?
  public func productMatching(ref: String, tag: Bool) throws -> Product? {
    var product: Product? = nil
    let keyPath = tag.then(\Product.deployTag.nameMatch).get(\Product.releaseBranch.nameMatch)
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
    generateNextBuild: .make(yaml: yaml.generateNextBuild),
    products: yaml.products
      .map { name, yaml in try .init(
        name: name,
        mainatiners: mainatiners
          .union(Set(yaml.mainatiners.get([]))),
        deployTag: .init(
          nameMatch: .init(yaml: yaml.deployTag.nameMatch),
          generateName: .make(yaml: yaml.deployTag.generateName),
          parseBuild: .make(yaml: yaml.deployTag.parseBuild),
          parseVersion: .make(yaml: yaml.deployTag.parseVersion)
        ),
        releaseBranch: .init(
          nameMatch: .init(yaml: yaml.releaseBranch.nameMatch),
          generateName: .make(yaml: yaml.releaseBranch.generateName),
          parseVersion: .make(yaml: yaml.releaseBranch.parseVersion)
        ),
        generateNextVersion: .make(yaml: yaml.generateNextVersion),
        generateHotfixVersion: .make(yaml: yaml.generateHotfixVersion)
      )},
    generateReleaseNotes: yaml.generateReleaseNotes
      .map(Configuration.Template.make(yaml:)),
    maxBuildsCount: yaml.maxBuildsCount
  )}
  public struct Product {
    public var name: String
    public var mainatiners: Set<String>
    public var deployTag: DeployTag
    public var releaseBranch: ReleaseBranch
    public var generateNextVersion: Configuration.Template
    public var generateHotfixVersion: Configuration.Template
    public func checkPermission(job: Json.GitlabJob) throws {
      guard mainatiners.contains(job.user.username)
      else { throw Thrown("Permission denied for \(job.user.username)") }
    }
    public struct DeployTag {
      public var nameMatch: Criteria
      public var generateName: Configuration.Template
      public var parseBuild: Configuration.Template
      public var parseVersion: Configuration.Template
    }
    public struct ReleaseBranch {
      public var nameMatch: Criteria
      public var generateName: Configuration.Template
      public var parseVersion: Configuration.Template
    }
  }
  public struct Build: Encodable {
    public var value: String
    public var sha: String
    public var ref: String
    public var tag: Bool
    public var review: UInt?
    public static func make(yaml: Yaml.Controls.Production.Build) throws -> Self { .init(
      value: yaml.build,
      sha: yaml.sha,
      ref: yaml.ref,
      tag: yaml.tag,
      review: yaml.review
    )}
    public static func make(
      value: String,
      sha: String,
      targer: String,
      review: UInt
    ) -> Self { .init(
      value: value,
      sha: sha,
      ref: targer,
      tag: false,
      review: review
    )}
    public static func make(
      value: String,
      sha: String,
      tag: String
    ) -> Self { .init(
      value: value,
      sha: sha,
      ref: tag,
      tag: true,
      review: nil
    )}
    public static func make(
      value: String,
      sha: String,
      branch: String
    ) -> Self { .init(
      value: value,
      sha: sha,
      ref: branch,
      tag: false,
      review: nil
    )}
  }
}
