import Foundation
import Facility
import FacilityPure
public struct ParseYamlSecret<T>: Query {
  public var cfg: Configuration
  public var secret: Configuration.Secret
  public var parse: Try.Of<AnyCodable.Dialect>.Of<AnyCodable>.Do<T>
  public typealias Reply = T
}
public extension Configuration {
  func parseApproalRules(
    approval: Fusion.Approval
  ) -> ParseYamlSecret<Fusion.Approval.Rules> { .init(
    cfg: self,
    secret: approval.rules,
    parse: { try .make(yaml: $0.read(Yaml.Review.Approval.Rules.self, from: $1)) }
  )}
  func parseHaters(approval: Fusion.Approval) -> ParseYamlSecret<[String: Set<String>]>? {
    guard let haters = approval.haters else { return nil }
    return .init(
      cfg: self,
      secret: haters,
      parse: { try $0.read([String: Set<String>].self, from: $1) }
    )
  }
}
