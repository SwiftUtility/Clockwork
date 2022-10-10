import Foundation
public struct AlphaNumeric {
  public var value: String
  public static func make(_ value: String) -> Self { .init(value: value) }
}
extension AlphaNumeric: Comparable, Hashable {
  public static func == (lhs: Self, rhs: Self) -> Bool { lhs.value == rhs.value }
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.value.compare(rhs.value, options: .numeric) == .orderedAscending
  }
  public func hash(into hasher: inout Hasher) { value.hash(into: &hasher) }
}
extension AlphaNumeric: Codable {
  public init(from decoder: Decoder) throws { try self.value = .init(from: decoder) }
  public func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
extension AlphaNumeric: CustomStringConvertible, CustomDebugStringConvertible {
  public var description: String { value.description }
  public var debugDescription: String { value.debugDescription }
}
extension String {
  public var alphaNumeric: AlphaNumeric { .init(value: self) }
}
