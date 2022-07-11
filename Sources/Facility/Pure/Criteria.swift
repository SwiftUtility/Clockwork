import Foundation
import Facility
public struct Criteria {
  var includes: [NSRegularExpression]
  var excludes: [NSRegularExpression]
  public init(includes: [String]? = nil, excludes: [String]? = nil) throws {
    self.includes = try includes.get([]).map {
      try NSRegularExpression(pattern: $0, options: [.anchorsMatchLines])
    }
    self.excludes = try excludes.get([]).map {
      try NSRegularExpression(pattern: $0, options: [.anchorsMatchLines])
    }
  }
  public init(yaml: Yaml.Criteria) throws {
    try self.includes = yaml.include.get([]).map {
      try NSRegularExpression(pattern: $0, options: [.anchorsMatchLines])
    }
    try self.excludes = yaml.exclude.get([]).map {
      try NSRegularExpression(pattern: $0, options: [.anchorsMatchLines])
    }
  }
  public var isEmpty: Bool { includes.isEmpty && excludes.isEmpty }
  public static func ensureNotEmpty(criteria: Self) throws -> Self {
    try criteria.isEmpty.then(criteria).get { throw Thrown("Empty criteria") }
  }
  public func isMet(_ string: String) -> Bool {
    let range = NSRange(string.startIndex..<string.endIndex, in: string)
    for exclude in excludes
    where exclude.firstMatch(in: string, range: range) != nil { return false }
    guard !includes.isEmpty else { return true }
    for include in includes
    where include.firstMatch(in: string as String, range: range) != nil { return true }
    return false
  }
}
