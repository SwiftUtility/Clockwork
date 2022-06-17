import Foundation
import Facility
public struct Asset {
  public var file: Files.Relative
  public var branch: Git.Branch
  public var commitMessageTemplate: String
  public static func make(
    yaml: Yaml.Asset
  ) throws -> Self { try .init(
    file: .init(value: yaml.file),
    branch: .init(name: yaml.branch),
    commitMessageTemplate: yaml.commitMessageTemplate
  )}
}
