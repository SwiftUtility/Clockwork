import Foundation
import Facility
public struct Production {
  public var builds: Asset
  public var versions: Asset
  public var createNextBuildTemplate: String
  public var products: [Product]
  public var releaseNotesTemplate: String?
  public var maxBuildsCount: Int?
  public func productMatching(ref: String, tag: Bool) throws -> Product {
    var product: Product? = nil
    let path = tag.then(\Product.deployTag.nameMatch).or(\Product.releaseBranch.nameMatch)
    for value in products {
      guard value[keyPath: path].isMet(ref) else { continue }
      if let product = product {
        throw Thrown("\(ref) matches both \(product.name) and \(value.name)")
      } else {
        product = value
      }
    }
    return try product.or { throw Thrown("No product match \(ref)") }
  }
  public func productMatching(name: String) throws -> Product { try products
    .first(where: { $0.name == name })
    .or { throw Thrown("No product \(name)") }
  }
  public static func make(
    mainatiners: Set<String>,
    yaml: Yaml.Controls.Production
  ) throws -> Self { try .init(
    builds: .make(yaml: yaml.builds),
    versions: .make(yaml: yaml.versions),
    createNextBuildTemplate: yaml.createNextBuildTemplate,
    products: yaml.products
      .map { name, yaml in try .init(
        name: name,
        mainatiners: mainatiners
          .union(Set(yaml.mainatiners.or([]))),
        deployTag: .init(
          nameMatch: .init(yaml: yaml.deployTag.nameMatch),
          createTemplate: yaml.deployTag.createTemplate,
          parseBuildTemplate: yaml.deployTag.parseBuildTemplate,
          parseVersionTemplate: yaml.deployTag.parseVersionTemplate
        ),
        releaseBranch: .init(
          nameMatch: .init(yaml: yaml.releaseBranch.nameMatch),
          createTemplate: yaml.releaseBranch.createTemplate,
          parseVersionTemplate: yaml.releaseBranch.parseVersionTemplate
        ),
        createNextVersionTemplate: yaml.createNextVersionTemplate,
        createHotfixVersionTemplate: yaml.createHotfixVersionTemplate
      )},
    releaseNotesTemplate: yaml.releaseNotesTemplate,
    maxBuildsCount: yaml.maxBuildsCount
  )}
  public struct Product {
    public var name: String
    public var mainatiners: Set<String>
    public var deployTag: DeployTag
    public var releaseBranch: ReleaseBranch
    public var createNextVersionTemplate: String
    public var createHotfixVersionTemplate: String
    public func checkPermission(job: Json.GitlabJob) throws {
      guard mainatiners.contains(job.user.username)
      else { throw Thrown("Permission denied for \(job.user.username)") }
    }
    public struct DeployTag {
      public var nameMatch: Criteria
      public var createTemplate: String
      public var parseBuildTemplate: String
      public var parseVersionTemplate: String
    }
    public struct ReleaseBranch {
      public var nameMatch: Criteria
      public var createTemplate: String
      public var parseVersionTemplate: String
    }
  }
}
