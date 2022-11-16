import Foundation
import Facility
public struct Slack {
  public var token: String
  public var storage: Configuration.Asset
  public var jira: Jira?
  public var gitlab: Gitlab?
  public var signals: [Signal]
  public static func make(token: String, yaml: Yaml.Slack) throws -> Self { try .init(
    token: token,
    storage: .make(yaml: yaml.storage),
    jira: yaml.jira.map(Jira.make(yaml:)),
    gitlab: yaml.gitlab.map(Gitlab.make(yaml:)),
    signals: yaml.signals.get([:]).map(Signal.make(mark:yaml:))
  )}
  public struct Gitlab {
    public var storage: Configuration.Asset
    public var tags: [String: Thread]
    public var reviews: [String: Thread]
    public var branches: [String: Thread]
    public static func make(yaml: Yaml.Slack.Gitlab) throws -> Self { try .init(
      storage: .make(yaml: yaml.storage),
      tags: yaml.tags
        .get([:])
        .reduce(into: [:], { $0[$1.key] = try .make(kind: .gitlabTag, name: $1.key, yaml: $1.value) }),
      reviews: yaml.reviews
        .get([:])
        .reduce(into: [:], { $0[$1.key] = try .make(kind: .gitlabReview, name: $1.key, yaml: $1.value) }),
      branches: yaml.branches
        .get([:])
        .reduce(into: [:], { $0[$1.key] = try .make(kind: .gitlabBranch, name: $1.key, yaml: $1.value) })
    )}
    public struct Storage {
      public var tags: [String: [String: Thread.Storage]]
      public var reviews: [String: [String: Thread.Storage]]
      public var branches: [String: [String: Thread.Storage]]
      public static func make(yaml: Yaml.Slack.Gitlab.Storage) -> Self { .init(
        tags: yaml.tags
          .get([:])
          .mapValues({ $0.reduce(into: [:], { $0[$1.key] = .make(
            kind: .gitlabTag,
            name: $1.key,
            yaml: $1.value)
          })}),
        reviews: yaml.reviews
          .get([:])
          .mapValues({ $0.reduce(into: [:], { $0[$1.key] = .make(
            kind: .gitlabReview,
            name: $1.key,
            yaml: $1.value)
          })}),
        branches: yaml.branches
          .get([:])
          .mapValues({ $0.reduce(into: [:], { $0[$1.key] = .make(
            kind: .gitlabBranch,
            name: $1.key,
            yaml: $1.value)
          })})
      )}
    }
  }
  public struct Jira {
    public var storage: Configuration.Asset
    public var epics: [String: Thread]
    public var issues: [String: Thread]
    public static func make(yaml: Yaml.Slack.Jira) throws -> Self { try .init(
      storage: .make(yaml: yaml.storage),
      epics: yaml.epics
        .get([:])
        .reduce(into: [:], { $0[$1.key] = try .make(kind: .jiraEpic, name: $1.key, yaml: $1.value) }),
      issues: yaml.issues
        .get([:])
        .reduce(into: [:], { $0[$1.key] = try .make(kind: .jiraIssue, name: $1.key, yaml: $1.value) })
    )}
    public struct Storage {
      public var epics: [String: [String: Thread.Storage]]
      public var issues: [String: [String: Thread.Storage]]
      public static func make(yaml: Yaml.Slack.Jira.Storage) -> Self { .init(
        epics: yaml.epics
          .get([:])
          .mapValues({ $0.reduce(into: [:], { $0[$1.key] = .make(
            kind: .jiraEpic,
            name: $1.key,
            yaml: $1.value)
          })}),
        issues: yaml.issues
          .get([:])
          .mapValues({ $0.reduce(into: [:], { $0[$1.key] = .make(
            kind: .jiraIssue,
            name: $1.key,
            yaml: $1.value)
          })})
      )}
    }
  }
  public struct Thread {
    public var kind: Kind
    public var name: String
    public var create: Signal
    public var update: [Signal]
    public static func make(
      kind: Kind,
      name: String,
      yaml: Yaml.Slack.Thread
    ) throws -> Self { try .init(
      kind: kind,
      name: name,
      create: .make(mark: name, yaml: yaml.create),
      update: yaml.update.get([:]).map(Signal.make(mark:yaml:))
    )}
    public enum Kind: String, Encodable {
      case gitlabTag
      case gitlabReview
      case gitlabBranch
      case jiraEpic
      case jiraIssue
    }
    public struct Storage: Encodable {
      public var kind: Kind
      public var name: String
      public var channel: String
      public var message: String
      public static func make(
        kind: Kind,
        name: String,
        yaml: Yaml.Slack.Thread.Storage
      ) -> Self { .init(
        kind: kind,
        name: name,
        channel: yaml.channel,
        message: yaml.message
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
  public struct Context: Encodable {
    var users: [String: Storage.User]
    var channels: [String: Storage.Channel]
    var mentions: [String: Storage.Mention]
    var thread: Thread.Storage?
    var person: String?
  }
  public struct Storage {
    public var users: [String: User]
    public var channels: [String: Channel]
    public var mentions: [String: Mention]
    public static func make(yaml: Yaml.Slack.Storage) -> Self { .init(
      users: yaml.users
        .get([:])
        .mapValues(User.make(yaml:)),
      channels: yaml.channels
        .get([:])
        .mapValues(Channel.make(yaml:)),
      mentions: yaml.mentions
        .get([:])
        .mapValues(Mention.make(yaml:))
    )}
    public struct User: Encodable {
      public var id: String
      public static func make(yaml: Yaml.Slack.Storage.User) -> Self { .init(
        id: yaml.id
      )}
    }
    public struct Channel: Encodable {
      public var id: String
      public static func make(yaml: Yaml.Slack.Storage.Channel) -> Self { .init(
        id: yaml.id
      )}
    }
    public struct Mention: Encodable {
      public var subteams: [String]?
      public var users: [String]?
      public static func make(yaml: Yaml.Slack.Storage.Mention) -> Self { .init(
        subteams: yaml.subteams,
        users: yaml.users
      )}
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
//
//
//
//
//
//public struct Chat {
//  public var storage: Configuration.Asset
//  public var slack
//  public static func make(yaml: Yaml.Chat) -> Self { .init(storage: <#T##Configuration.Asset#>)}
//  public struct Storage: Decodable {
//    public var tags: [String: [String: Thread]]
//    public var tasks: [String: [String: Thread]]
//    public var reviews: [UInt: [String: Thread]]
//    public var branches: [String: [String: Thread]]
//    public struct Thread: Decodable {
//      public var name: String
//      public var channel: String
//      public var message: String
//    }
//  }
//  public struct Slack {
//    public var token: String
//    public var createThread: [String: [String: [Signal]]]
//    public var updateThread: [String: [String: [Signal]]]
//    public var signals: [String: [Signal]]
//  }
//  public struct Signal {
//    public var mark: String?
//    public var method: String?
//    public var body: Configuration.Template
//    public static func make(
//      acc: inout [String: [Self]],
//      yaml: Dictionary<String, Yaml.Chat.Signal>.Element
//    ) throws {
//      for event in yaml.value.events {
//        try acc[event] = acc[event].get([]) + [.init(
//          mark: yaml.key,
//          method: yaml.value.method,
//          body: .make(yaml: yaml.value.body)
//        )]
//      }
//    }
//  }
//}
//public struct Slack {
//  public var token: String
//  public var signals: [String: [Signal]]
//  public static func make(token: String, yaml: Yaml.Slack) throws -> Self { try .init(
//    token: token,
//    signals: yaml.signals.reduce(into: [:], Signal.make(acc:yaml:))
//  )}
//  public struct Signal {
//    public var mark: String
//    public var method: String
//    public var body: Configuration.Template
//    public static func make(
//      acc: inout [String: [Self]],
//      yaml: Dictionary<String, Yaml.Slack.Signal>.Element
//    ) throws {
//      for event in yaml.value.events {
//        try acc[event] = acc[event].get([]) + [.init(
//          mark: yaml.key,
//          method: yaml.value.method,
//          body: .make(yaml: yaml.value.body)
//        )]
//      }
//    }
//  }
//}
