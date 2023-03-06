import Foundation
import Facility
public enum Files {
  public struct Absolute {
    public let value: String
    public init(value: String) throws {
      try value.isEmpty.then { throw Thrown("Empty absolute path") }
      try value.starts(with: "/").else { throw Thrown("Not absolute path \(value)") }
      self.value = value
    }
    public func makeResolve(path: String) -> ResolveAbsolute {
      .init(path: path, relativeTo: self)
    }
  }
  public struct Relative: Hashable {
    public let value: String
    public static func make(value: String) throws -> Self {
      try value.starts(with: "/").then { throw Thrown("Not relative path \(value)") }
      return .init(value: value)
    }
    public static var empty: Self { .init(value: "") }
  }
  public struct ReadFile: Query {
    public var file: Absolute
    public init(file: Absolute) throws {
      self.file = file
    }
    public typealias Reply = Data
  }
  public struct ResolveAbsolute: Query {
    public var path: String
    public var relativeTo: Absolute?
    public static func make(path: String) -> Self {
      .init(path: path, relativeTo: nil)
    }
    public typealias Reply = Absolute
  }
  public struct WriteFile: Query {
    public var file: Absolute
    public var data: Data
    public init(file: Absolute, data: Data) {
      self.file = file
      self.data = data
    }
    public typealias Reply = Void
  }
  public struct CreateFile: Query {
    public var file: Absolute
    public var data: Data
    public init(file: Absolute, data: Data) {
      self.file = file
      self.data = data
    }
    public typealias Reply = Void
  }
  public struct ListFileLines: Query {
    public var file: Absolute
    public init(file: Absolute) {
      self.file = file
    }
    public typealias Reply = AnyIterator<String>
  }
  public struct ListFileSystem: Query {
    public var path: Absolute
    public var include: Include
    public init(include: Include, path: Absolute) {
      self.path = path
      self.include = include
    }
    public typealias Reply = [String]
    public enum Include: Equatable {
      case files
      case directories
      public var files: Bool { self == .files }
      public var directories: Bool { self == .directories }
    }
  }
}
