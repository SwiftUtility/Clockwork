import Foundation
import Facility
extension Review {
  public struct Target: Encodable {
    public var name: String
    public var kind: Kind
    public static func merges(targets: [Self]) -> [String]? {
      let targets = targets
        .filter(\.kind.forward.not)
        .map(\.name.alphaNumeric)
        .sorted()
        .map(\.value)
      return targets.isEmpty.else(targets)
    }
    public static func forwards(targets: [Self]) -> [String]? {
      let targets = targets
        .filter(\.kind.forward)
        .map(\.name.alphaNumeric)
        .sorted()
        .map(\.value)
      return targets.isEmpty.else(targets)
    }
    public static func sorted(targets: [Self]) -> [Self] {
      targets.sorted(by: { $0.name.alphaNumeric < $1.name.alphaNumeric })
    }
    public enum Kind: String, Encodable {
      case merge
      case forward
      public var forward: Bool { return self == .forward }
    }
  }
}
extension Git.Branch {
  public func makeTarget(forward: Bool) -> Review.Target { .init(
    name: name,
    kind: forward.then(.forward).get(.merge)
  )}
}
