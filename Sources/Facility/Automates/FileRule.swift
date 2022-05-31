import Foundation
import Facility
public struct FileRule {
  public var rule: String
  public var files: Criteria
  public var lines: Criteria
  public init(yaml: Yaml.FileRule) throws {
    self.rule = yaml.rule
    self.files = try .init(includes: yaml.file?.include, excludes: yaml.file?.exclude)
    self.lines = try .init(includes: yaml.line?.include, excludes: yaml.line?.exclude)
    if files.isEmpty && lines.isEmpty {
      throw Thrown("Empty rule \(yaml.rule)")
    }
  }
  public struct Issue: Codable {
    public var rule: String
    public var file: String
    public var line: Int?
    public init(rule: String, file: String, line: Int? = nil) {
      self.rule = rule
      self.file = file
      self.line = line
    }
    public var logMessage: String {
      guard let line = line else { return "\(file): \(rule)" }
      return "\(file):\(line): \(rule)"
    }
  }
}
