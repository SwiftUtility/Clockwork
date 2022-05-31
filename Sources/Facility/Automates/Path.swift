import Foundation
import Facility
public enum Path {
  public struct Absolute {
    public let path: String
    public init(path: String) throws {
      try path.isEmpty.then { throw Thrown("Empty absolute path") }
      try path.starts(with: "/").else { throw Thrown("Not absolute path \(path)") }
      self.path = path
    }
  }
  public struct Relative {
    public let path: String
    public init(path: String) throws {
      try path.starts(with: "/").then { throw Thrown("Not relative path \(path)") }
      self.path = path
    }
  }
}
