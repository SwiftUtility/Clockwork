//import Foundation
//import Facility
//import FacilityPure
//public struct ParseYamlSecret<T>: Query {
//  public var cfg: Configuration
//  public var secret: Configuration.Secret
//  public var parse: Try.Of<AnyCodable.Dialect>.Of<AnyCodable>.Do<T>
//  public typealias Reply = T
//}
//public extension Configuration {
//  func parseReviewRules(
//    review: Review
//  ) -> ParseYamlSecret<Review.Rules> { .init(
//    cfg: self,
//    secret: review.rules,
//    parse: { try .make(yaml: $0.read(Yaml.Review.Rules.self, from: $1)) }
//  )}
//}
