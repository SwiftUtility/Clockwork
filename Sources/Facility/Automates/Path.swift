import Foundation
import Facility
public enum Path {
  public struct Absolute {
    public let value: String
    public init(value: String) throws {
      try value.isEmpty.then { throw Thrown("Empty absolute path") }
      try value.starts(with: "/").else { throw Thrown("Not absolute path \(value)") }
      self.value = value
    }
  }
  public struct Relative {
    public let value: String
    public init(value: String) throws {
      try value.starts(with: "/").then { throw Thrown("Not relative path \(value)") }
      self.value = value
    }
  }
}
