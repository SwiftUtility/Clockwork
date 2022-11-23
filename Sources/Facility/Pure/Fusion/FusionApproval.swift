import Foundation
import Facility
extension Fusion {
  public struct Approval {
    public var rules: Configuration.Secret
    public var statuses: Configuration.Asset
    public var approvers: Configuration.Asset
    public var haters: Configuration.Secret?
    public static func make(yaml: Yaml.Review.Approval) throws -> Self { try .init(
      rules: .make(yaml: yaml.rules),
      statuses: .make(yaml: yaml.statuses),
      approvers: .make(yaml: yaml.approvers),
      haters: yaml.haters
        .map(Configuration.Secret.make(yaml:))
    )}
  }
}
