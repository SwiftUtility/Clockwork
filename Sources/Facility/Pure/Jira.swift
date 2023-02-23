import Foundation
import Facility
public struct Jira {
  public var url: String
  public var token: String
  public var issue: NSRegularExpression
  public var chains: [Chain]
  public var info: Info { .init(url: url) }
  public static func make(
    url: String,
    token: String,
    yaml: Yaml.Jira
  ) throws -> Self { try .init(
    url: url,
    token: token,
    issue: NSRegularExpression(pattern: yaml.issue, options: [.anchorsMatchLines]),
    chains: yaml.chains.get([:]).map(Chain.make(mark:yaml:))
  )}
  public struct Info: Encodable {
    public var url: String
    public var issue: String?
    public var chain: [AnyCodable?] = []
  }
  public struct Chain {
    public var mark: String
    public var links: [Link]
    public var events: [[String]]
    public static func make(mark: String, yaml: Yaml.Jira.Chain) throws -> Self { try .init(
      mark: mark,
      links: yaml.links.map({ yaml in try .init(
        url: .make(yaml: yaml.url),
        body: yaml.body.map(Configuration.Template.make(yaml:)),
        method: yaml.method.get("GET")
      )}),
      events: yaml.events.map({ $0.components(separatedBy: "/") })
    )}
    public struct Link {
      public var url: Configuration.Template
      public var body: Configuration.Template?
      public var method: String
    }
  }
}
