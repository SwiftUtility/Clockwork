import Foundation
import Facility
public struct Chat {
  public var storage: Configuration.Asset
  public var slack
  public static func make(yaml: Yaml.Chat) -> Self { .init(storage: <#T##Configuration.Asset#>)}
  public struct Storage: Decodable {
    public var tags: [String: [String: Thread]]
    public var tasks: [String: [String: Thread]]
    public var reviews: [UInt: [String: Thread]]
    public var branches: [String: [String: Thread]]
    public struct Thread: Decodable {
      public var name: String
      public var channel: String
      public var message: String
    }
  }
  public struct Slack {
    public var token: String
    public var createThread: [String: [String: [Signal]]]
    public var updateThread: [String: [String: [Signal]]]
    public var signals: [String: [Signal]]
  }
  public struct Signal {
    public var mark: String?
    public var method: String?
    public var body: Configuration.Template
    public static func make(
      acc: inout [String: [Self]],
      yaml: Dictionary<String, Yaml.Chat.Signal>.Element
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
