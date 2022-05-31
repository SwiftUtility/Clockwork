import Foundation
import Facility
import FacilityAutomates
public struct ResolveAbsolutePath: Query {
  public var path: String
  public var relativeTo: Path.Absolute?
  public static func make(path: String) -> Self {
    .init(path: path, relativeTo: nil)
  }
  public typealias Reply = Path.Absolute
}
public extension Path.Absolute {
  func makeResolve(path: String) -> ResolveAbsolutePath {
    .init(path: path, relativeTo: self)
  }
}
