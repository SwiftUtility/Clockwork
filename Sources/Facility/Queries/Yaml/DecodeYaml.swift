import Foundation
import Facility
public struct DecodeYaml: Query {
  public var content: String
  public init(content: String) {
    self.content = content
  }
  public typealias Reply = AnyCodable
}
