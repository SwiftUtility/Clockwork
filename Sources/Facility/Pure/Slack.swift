import Foundation
import Facility
public struct Slack {
  public var token: String
  public var storage: Configuration.Asset
  public var info: Info
//  public var jira: Jira?
//  public var gitlab: Gitlab?
  public var signals: [Signal]
  public static func make(
    token: String,
    yaml: Yaml.Slack
  ) throws -> Self { try .init(
    token: token,
    storage: .make(yaml: yaml.storage),
    info: .init(users: [:], channels: [:], mentions: [:]),
//    jira: yaml.jira.map(Jira.make(yaml:)),
//    gitlab: yaml.gitlab.map(Gitlab.make(yaml:)),
    signals: yaml.signals.get([:]).map(Signal.make(mark:yaml:))
  )}
  public struct RegisterUser: Query {
    public var cfg: Configuration
    public var slack: String
    public var gitlab: String
    public static func make(
      cfg: Configuration,
      slack: String,
      gitlab: String
    ) -> Self { .init(
      cfg: cfg,
      slack: slack,
      gitlab: gitlab
    )}
    public typealias Reply = Void
  }
  public struct Thread {
    public var name: String
    public var create: Signal
    public var update: [Signal]
    public static func make(
      name: String,
      yaml: Yaml.Slack.Thread
    ) throws -> Self { try .init(
      name: name,
      create: .make(mark: name, yaml: yaml.create),
      update: yaml.update.get([:]).map(Signal.make(mark:yaml:))
    )}
  }
  public struct Signal {
    public var events: [[String]]
    public var mark: String
    public var method: String
    public var body: Configuration.Template
    public static func make(
      mark: String,
      yaml: Yaml.Slack.Signal
    ) throws -> Self { try .init(
      events: yaml.events.map({ $0.components(separatedBy: "/") }),
      mark: mark,
      method: yaml.method.get("chat.postMessage"),
      body: .make(yaml: yaml.body))
    }
  }
  public struct Info: Encodable {
    var users: [String: String]
    var channels: [String: String]
    var mentions: [String: String]
    var thread: Storage.Thread?
    var person: String?
    public static func make(storage: Storage) -> Self { .init(
      users: storage.users,
      channels: storage.channels,
      mentions: storage.mentions
    )}
  }
  public struct Storage {
    public var users: [String: String]
    public var channels: [String: String]
    public var mentions: [String: String]
    public var tags: [String: [String: Thread]]
    public var issues: [String: [String: Thread]]
    public var reviews: [String: [String: Thread]]
    public var branches: [String: [String: Thread]]
    public var serialized: String {
      var result = ""
      if users.isEmpty.not {
        result += "users:\n"
        result += users.map({ "  '\($0.key)': '\($0.value)'\n" }).joined()
      }
      if channels.isEmpty.not {
        result += "channels:\n"
        result += channels.map({ "  '\($0.key)': '\($0.value)'\n" }).joined()
      }
      if mentions.isEmpty.not {
        result += "mentions:\n"
        result += mentions.map({ "  '\($0.key)': '\($0.value)'\n" }).joined()
      }
      result += Thread.serialize(kind: "tags", map: tags)
      result += Thread.serialize(kind: "issues", map: issues)
      result += Thread.serialize(kind: "reviews", map: reviews)
      result += Thread.serialize(kind: "branches", map: branches)
      if result.isEmpty { result = "{}\n" }
      return result
    }
    public static func make(yaml: Yaml.Slack.Storage) -> Self { .init(
      users: yaml.users.get([:]),
      channels: yaml.channels.get([:]),
      mentions: yaml.mentions.get([:]),
      tags: yaml.tags.get([:]).mapValues(Thread.make(yaml:)),
      issues: yaml.issues.get([:]).mapValues(Thread.make(yaml:)),
      reviews: yaml.reviews.get([:]).mapValues(Thread.make(yaml:)),
      branches: yaml.branches.get([:]).mapValues(Thread.make(yaml:))
    )}
    public struct Thread: Encodable {
      public var name: String
      public var channel: String
      public var message: String
      var line: String { "    '\(name)': {channel: '\(channel)', message: '\(message)'}\n" }
      public static func make(name: String, yaml: Yaml.Slack.Storage.Thread) -> Self { .init(
        name: name, channel: yaml.channel, message: yaml.message
      )}
      public static func make(yaml: [String: Yaml.Slack.Storage.Thread]) -> [String: Self] {
        yaml.reduce(into: [:], { $0[$1.key] = .make(name: $1.key, yaml: $1.value) })
      }
      static func serialize(kind: String, map: [String: [String: Self]]) -> String {
        var result = ""
        let keys = map.filter(\.value.isEmpty.not).keys.sorted()
        if keys.isEmpty.not {
          result += "\(kind):\n"
          for key in keys {
            result += "  '\(key)':\n"
            result += map[key].get([:]).keys.sorted()
              .compactMap({ map[key]?[$0]?.line })
              .joined()
          }
        }
        return result
      }
    }
  }
}
public extension GenerateInfo {
  func triggers(signal: Slack.Signal) -> Bool {
    outer: for signal in signal.events {
      guard event.count >= signal.count else { continue }
      for index in signal.indices {
        guard event[index] == signal[index] else { continue outer }
      }
      return true
    }
    return false
  }
}
