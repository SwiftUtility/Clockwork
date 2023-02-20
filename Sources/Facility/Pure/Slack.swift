import Foundation
import Facility
public struct Slack {
  public var token: String
  public var storage: Configuration.Asset
  public var info: Info
  public var signals: [Signal]
  public var directs: [Signal]
  public var tags: [Thread]
  public var issues: [Thread]
  public var reviews: [Thread]
  public var branches: [Thread]
  public static func make(
    token: String,
    yaml: Yaml.Slack
  ) throws -> Self { try .init(
    token: token,
    storage: .make(yaml: yaml.storage),
    info: .init(users: [:], channels: [:], mentions: [:]),
    signals: yaml.signals.get([:]).map(Signal.make(mark:yaml:)),
    directs: yaml.directs.get([:]).map(Signal.make(mark:yaml:)),
    tags: yaml.tags.get([:]).map(Thread.make(name:yaml:)),
    issues: yaml.issues.get([:]).map(Thread.make(name:yaml:)),
    reviews: yaml.reviews.get([:]).map(Thread.make(name:yaml:)),
    branches: yaml.branches.get([:]).map(Thread.make(name:yaml:))
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
  public struct Send: Query {
    public var cfg: Configuration
    public var reports: [Report]
    public static func make(
      cfg: Configuration,
      reports: [Report]
    ) -> Self { .init(
      cfg: cfg,
      reports: reports
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
    public struct Update: Encodable {
      public var update: String
      public var channel: String
      public var message: String
      public static func make(signal: Signal, thread: Storage.Thread) -> Self { .init(
        update: signal.mark,
        channel: thread.channel,
        message: thread.message
      )}
    }
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
    public var users: [String: String]
    public var channels: [String: String]
    public var mentions: [String: String]
    public var thread: Thread.Update?
    public var person: String?
    public static func make(storage: Storage) -> Self { .init(
      users: storage.users,
      channels: storage.channels,
      mentions: storage.mentions
    )}
  }
  public struct Storage {
    public var slack: Slack
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
        result += users.map({ "  '\($0.key)': '\($0.value)'\n" }).sorted().joined()
      }
      if channels.isEmpty.not {
        result += "channels:\n"
        result += channels.map({ "  '\($0.key)': '\($0.value)'\n" }).sorted().joined()
      }
      if mentions.isEmpty.not {
        result += "mentions:\n"
        result += mentions.map({ "  '\($0.key)': '\($0.value)'\n" }).sorted().joined()
      }
      result += Thread.serialize(kind: "tags", map: tags)
      result += Thread.serialize(kind: "issues", map: issues)
      result += Thread.serialize(kind: "reviews", map: reviews)
      result += Thread.serialize(kind: "branches", map: branches)
      if result.isEmpty { result = "{}\n" }
      return result
    }
    public static func make(slack: Slack, yaml: Yaml.Slack.Storage) -> Self { .init(
      slack: slack,
      users: yaml.users.get([:]),
      channels: yaml.channels.get([:]),
      mentions: yaml.mentions.get([:]),
      tags: yaml.tags.get([:]).mapValues(Thread.make(yaml:)),
      issues: yaml.issues.get([:]).mapValues(Thread.make(yaml:)),
      reviews: yaml.reviews.get([:]).mapValues(Thread.make(yaml:)),
      branches: yaml.branches.get([:]).mapValues(Thread.make(yaml:))
    )}
    public struct Thread {
      public var name: String
      public var channel: String
      public var message: String
      var line: String { "    '\(name)': {channel: '\(channel)', message: '\(message)'}\n" }
      public static func make(name: String, yaml: Yaml.Slack.Storage.Thread) -> Self { .init(
        name: name, channel: yaml.channel, message: yaml.message
      )}
      public static func make(name: String, json: Json.SlackMessage) -> Self { .init(
        name: name, channel: json.channel, message: json.ts
      )}
      public static func make(yaml: [String: Yaml.Slack.Storage.Thread]) -> [String: Self] { yaml
        .map(Self.make(name:yaml:))
        .indexed(\.name)
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
