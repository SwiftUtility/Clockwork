import Foundation
import Facility
public struct Cocoapods {
  public var path: Ctx.Sys.Relative
  public var specs: [Spec]
  public static func make(
    path: Ctx.Sys.Relative,
    yaml: Yaml.Cocoapods
  ) throws -> Self { try .init(
    path: path,
    specs: yaml.specs
      .get([])
      .map(Spec.make(yaml:))
  )}
  public var yaml: String {
    var result: [String] = []
    result.append("specs:\n")
    for spec in specs {
      result.append("- name: '\(spec.name)'\n")
      result.append("  url: '\(spec.url)'\n")
      result.append("  sha: '\(spec.sha.value)'\n")
    }
    return result.joined()
  }
  public struct Spec {
    public var name: String
    public var url: String
    public var sha: Ctx.Git.Sha
    public static func make(yaml: Yaml.Cocoapods.Spec) throws -> Self { try .init(
      name: yaml.name,
      url: yaml.url,
      sha: .make(value: yaml.sha)
    )}
  }
}
