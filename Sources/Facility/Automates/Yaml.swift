import Foundation
import Facility
public enum Yaml {
  public struct Profile: Decodable {
    public var controls: Controls
    public var fileApproval: String?
    public var fileRules: String?
    public var obsolete: Criteria?
    public var stencil: Stencil?
    public var integrationJobTemplate: String?
    public struct Controls: Decodable {
      public var branch: String
      public var file: String
    }
  }
  public struct Controls: Decodable {
    public var notifications: String?
    public var awardApproval: String?
    public var stencil: Stencil?
    public var slackHooks: [String: Token]?
    public var assets: Assets?
    public var gitlab: Gitlab?
    public var requisites: [String: Requisite]?
    public var review: Review?
    public var replication: Replication?
    public var integration: Integration?
  }
  public struct Assets: Decodable {
    public var branch: String
    public var builds: String?
    public var versions: String?
    public var vacationers: String?
  }
  public struct Review: Decodable {
    public var messageTemplate: String?
    public var titleRule: Criteria?
  }
  public struct Replication: Decodable {
    public var messageTemplate: String
    public var target: String
    public var prefix: String?
    public var source: Criteria
  }
  public struct Integration: Decodable {
    public var messageTemplate: String
    public var prefix: String?
    public var rules: [Rule]
    public var users: [String]?
    public struct Rule: Decodable {
      public var users: [String]?
      public var source: Criteria
      public var target: Criteria
    }
  }
  public struct Gitlab: Decodable {
    public var botLogin: String
    public var botToken: Token
    public var parentPipeline: String
    public var parentReview: String
    public var parentProfile: String
  }
  public struct Stencil: Decodable {
    public var templates: String
    public var custom: String?
  }
  public struct Requisite: Decodable {
    public var provisions: String?
    public var keychain: Keychain?
  }
  public struct Keychain: Decodable {
    public var crypto: String
    public var password: Token
  }
  public struct Token: Decodable {
    public var value: String?
    public var envVar: String?
    public var envFile: String?
  }
  public struct AwardApproval: Decodable {
    public var holders: Holders
    public var groups: [String: Group]
    public var sanity: String?
    public var emergency: String?
    public var replication: String?
    public var integrationSourceBranch: [String: Criteria]?
    public var targetBranch: [String: Criteria]?
    public var personal: [String: [String]]?
    public struct Group: Decodable {
      public var award: String
      public var quorum: Int
      public var reserve: [String]?
      public var optional: [String]?
      public var required: [String]?
    }
    public struct Holders: Decodable {
      public var award: String
      public var users: [String]
    }
  }
  public struct Notifications: Decodable {
    public var slackHooks: [SlackHook]?
    public var jsonStdout: [JsonStdout]?
    public struct SlackHook: Decodable {
      public var hook: String
      public var template: String
      public var userName: String?
      public var channel: String?
      public var emojiIcon: String?
      public var events: [String]
    }
    public struct JsonStdout: Decodable {
      public var template: String
      public var events: [String]
    }
  }
  public struct FileRule: Decodable {
    public var rule: String
    public var file: Criteria?
    public var line: Criteria?
  }
  public struct Criteria: Decodable {
    var include: [String]?
    var exclude: [String]?
  }
}
