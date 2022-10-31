import Foundation
import Facility
public struct Slack {
  public var token: String
  public var signals: [String: [Signal]]
  public static func make(token: String, yaml: Yaml.Slack) throws -> Self { try .init(
    token: token,
    signals: yaml.signals.reduce(into: [:], Signal.make(acc:yaml:))
  )}
  public struct Signal {
    public var mark: String
    public var method: String
    public var body: Configuration.Template
    public static func make(
      acc: inout [String: [Self]],
      yaml: Dictionary<String, Yaml.Slack.Signal>.Element
    ) throws {
      for event in yaml.value.events {
        try acc[event] = acc[event].get([]) + [.init(
          mark: yaml.key,
          method: yaml.value.method,
          body: .make(yaml: yaml.value.body)
        )]
      }
    }
  }
}
