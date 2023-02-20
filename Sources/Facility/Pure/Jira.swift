import Foundation
import Facility
public struct Jira {
  public var url: String
  public var token: String
  public var issue: NSRegularExpression
  public var issues: [Signal]
  public var info: Info { .init(url: url) }
  public static func make(
    url: String,
    token: String,
    yaml: Yaml.Jira
  ) throws -> Self { try .init(
    url: url,
    token: token,
    issue: NSRegularExpression(pattern: yaml.issue, options: [.anchorsMatchLines]),
    issues: yaml.issues
      .get([:])
      .map(Signal.make(mark:yaml:))
  )}
  public struct Info: Encodable {
    public var url: String
    public var issue: String?
  }
  public struct Signal {
    public var mark: String
    public var url: Configuration.Template
    public var body: Configuration.Template
    public var method: String
    public var events: [[String]]
    public static func make(mark: String, yaml: Yaml.Jira.Signal) throws -> Self { try .init(
      mark: mark,
      url: .make(yaml: yaml.url),
      body: .make(yaml: yaml.body),
      method: yaml.method,
      events: yaml.events.map({ $0.components(separatedBy: "/") })
    )}
  }
}
