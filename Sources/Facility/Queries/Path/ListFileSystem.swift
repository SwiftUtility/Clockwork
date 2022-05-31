import Foundation
import Facility
public struct ListFileSystem: Query {
  public var path: String
  public var include: Include
  public init(path: String, include: Include) {
    self.path = path
    self.include = include
  }
  public typealias Reply = AnyIterator<String>
  public enum Include: Equatable {
    case files
    case directories
    public var files: Bool { self == .files }
    public var directories: Bool { self == .directories }
  }
}
