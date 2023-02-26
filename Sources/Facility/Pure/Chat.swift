import Foundation
import Facility
public enum Chat {
  case slack(Slack.Chat)
  case rocket(Rocket.Chat)
  public var storage: Configuration.Asset {
    switch self {
    case .slack(let slack): return slack.storage
    case .rocket(let rocket): return rocket.storage
    }
  }
  public var diffusion: Diffusion {
    switch self {
    case .slack(let slack): return slack.diffusion
    case .rocket(let rocket): return rocket.diffusion
    }
  }
  public var kind: Kind {
    switch self {
    case .slack: return .slack
    case .rocket: return .rocket
    }
  }
  public enum Kind: String, Encodable {
    case slack
    case rocket
  }
  public struct Register: Query {
    public var cfg: Configuration
    public var kind: Kind
    public var user: String
    public var gitlab: String
    public static func make(
      cfg: Configuration,
      kind: Kind,
      user: String,
      gitlab: String
    ) -> Self { .init(
      cfg: cfg,
      kind: kind,
      user: user,
      gitlab: gitlab
    )}
    public typealias Reply = Void
  }
  public struct Clean: Query {
    public var cfg: Configuration
    public var tags: Set<String> = []
    public var issues: Set<String> = []
    public var reviews: Set<String> = []
    public var branches: Set<String> = []
    public typealias Reply = Void
  }
  public struct Slack {
    public var token: Configuration.Secret
    public var storage: Configuration.Asset
    public var diffusion: Diffusion
    public static func make(yaml: Yaml.Chat.Slack) throws -> Self { try .init(
      token: .make(yaml: yaml.token),
      storage: .make(yaml: yaml.storage),
      diffusion: .make(yaml: yaml.diffusion)
    )}
    public func makeChat(
      token: String,
      slack: Slack
    ) throws -> Chat { .init(
      token: token,
      storage: slack.storage,
      diffusion: slack.diffusion
    )}
    public struct Chat {
      public var token: String
      public var storage: Configuration.Asset
      public var diffusion: Diffusion
    }
  }
  public struct Rocket {
    public var url: Configuration.Secret
    public var user: Configuration.Secret
    public var token: Configuration.Secret
    public var storage: Configuration.Asset
    public var diffusion: Diffusion
    public static func make(yaml: Yaml.Chat.Rocket) throws -> Self { try .init(
      url: .make(yaml: yaml.url),
      user: .make(yaml: yaml.user),
      token: .make(yaml: yaml.token),
      storage: .make(yaml: yaml.storage),
      diffusion: .make(yaml: yaml.diffusion)
    )}
    public func makeChat(
      url: String,
      user: String,
      token: String,
      rocket: Rocket
    ) throws -> Chat { .init(
      url: url,
      user: user,
      token: token,
      storage: rocket.storage,
      diffusion: rocket.diffusion
    )}
    public struct Chat {
      public var url: String
      public var user: String
      public var token: String
      public var storage: Configuration.Asset
      public var diffusion: Diffusion
    }
  }
  public struct Diffusion {
    public var signals: [Signal]
    public var directs: [Signal]
    public var tags: [Thread]
    public var issues: [Thread]
    public var reviews: [Thread]
    public var branches: [Thread]
    public static func make(
      yaml: Yaml.Chat.Diffusion
    ) throws -> Self { try .init(
      signals: yaml.signals.get([:]).map(Signal.make(mark:yaml:)),
      directs: yaml.directs.get([:]).map(Signal.make(mark:yaml:)),
      tags: yaml.tags.get([:]).map(Thread.make(name:yaml:)),
      issues: yaml.issues.get([:]).map(Thread.make(name:yaml:)),
      reviews: yaml.reviews.get([:]).map(Thread.make(name:yaml:)),
      branches: yaml.branches.get([:]).map(Thread.make(name:yaml:))
    )}
    public struct Thread {
      public var name: String
      public var create: Signal
      public var update: [Signal]
      public static func make(
        name: String,
        yaml: Yaml.Chat.Diffusion.Thread
      ) throws -> Self { try .init(
        name: name,
        create: .make(mark: name, yaml: yaml.create),
        update: yaml.update.get([:]).map(Signal.make(mark:yaml:))
      )}
    }
    public struct Signal {
      public var mark: String
      public var path: String
      public var method: String
      public var body: Configuration.Template
      public var events: [[String]]
      public static func make(
        mark: String,
        yaml: Yaml.Chat.Diffusion.Signal
      ) throws -> Self { try .init(
        mark: mark,
        path: yaml.path,
        method: yaml.method.get("POST"),
        body: .make(yaml: yaml.body),
        events: yaml.events.map({ $0.components(separatedBy: "/") })
      )}
    }
  }
  public struct Storage {
    public var chat: Chat
    public var users: [String: String]
    public var channels: [String: String]
    public var mentions: [String: String]
    public var tags: [String: [String: Thread]]
    public var issues: [String: [String: Thread]]
    public var reviews: [String: [String: Thread]]
    public var branches: [String: [String: Thread]]
    public var info: Info { .init(
      kind: chat.kind,
      users: users,
      channels: channels,
      mentions: mentions
    )}
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
    public static func make(chat: Chat, yaml: Yaml.Chat.Storage) -> Self { .init(
      chat: chat,
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
      public static func make(name: String, slack: Json.SlackMessage) -> Self { .init(
        name: name, channel: slack.channel, message: slack.ts
      )}
      public static func make(name: String, rocket: Json.RocketReply) -> Self { .init(
        name: name, channel: rocket.message.rid, message: rocket.message.id
      )}
      public static func make(name: String, yaml: Yaml.Chat.Storage.Thread) -> Self { .init(
        name: name, channel: yaml.channel, message: yaml.message
      )}
      public static func make(yaml: [String: Yaml.Chat.Storage.Thread]) -> [String: Self] { yaml
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
  public struct Info: Encodable {
    public var kind: Kind
    public var users: [String: String]
    public var channels: [String: String]
    public var mentions: [String: String]
    public var thread: Thread?
    public var person: String?
    public struct Thread: Encodable {
      public var update: String
      public var channel: String
      public var message: String
      public static func make(signal: Diffusion.Signal, thread: Storage.Thread) -> Self { .init(
        update: signal.mark,
        channel: thread.channel,
        message: thread.message
      )}
    }
  }
}
public extension GenerateInfo {
  func triggers(signal: Chat.Diffusion.Signal) -> Bool {
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
