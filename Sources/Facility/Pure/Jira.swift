import Foundation
import Facility
public struct Jira {
  public var url: String
  public var rest: String
  public var token: String
  public var issues: [Signal]
  public var context: Context { .init(url: url) }
  public static func make(
    url: String,
    rest: String,
    token: String,
    yaml: Yaml.Jira
  ) throws -> Self { try .init(
    url: url,
    rest: rest,
    token: token,
    issues: yaml.issues
      .get([:])
      .map(Signal.make(mark:yaml:))
  )}
  public struct Context: Encodable {
    var url: String
    var epics: [String]?
    var issue: String?
    var issues: [String]?
  }
  public struct Signal {
    public var mark: String
    public var url: Configuration.Template
    public var body: Configuration.Template
    public var events: [[String]]
    public static func make(mark: String, yaml: Yaml.Jira.Signal) throws -> Self { try .init(
      mark: mark,
      url: .make(yaml: yaml.url),
      body: .make(yaml: yaml.body),
      events: yaml.events.map({ $0.components(separatedBy: "/") })
    )}
  }
}
