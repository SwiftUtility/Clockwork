import Foundation
import Facility
public enum Yaml {
  public struct Profile: Decodable {
    public var controls: Controls
    public var codeOwnage: String?
    public var fileTaboos: String?
    public var obsolescence: Criteria?
    public var templates: String?
    public var exportBuildContext: Template?
    public var exportCurrentVersions: Template?
    public struct FileTaboo: Decodable {
      public var rule: String
      public var file: Criteria?
      public var line: Criteria?
    }
    public struct Controls: Decodable {
      public var path: String
      public var branch: String
    }
  }
  public struct Controls: Decodable {
    public var mainatiners: [String]?
    public var gitlabCi: GitlabCi?
    public var communication: String
    public var awardApproval: String?
    public var production: String?
    public var requisition: String?
    public var fusion: String?
    public var templates: String?
    public var context: String?
    public var forbiddenCommits: Asset?
    public struct Production: Decodable {
      public var mainatiners: [String]?
      public var builds: Asset
      public var versions: Asset
      public var bumpBuildNumber: Template
      public var deployTag: DeployTag
      public var releaseBranch: ReleaseBranch
      public var products: [String: Product]
      public var accessoryBranch: AccessoryBranch?
      public var maxBuildsCount: Int?
      public struct Product: Decodable {
        public var mainatiners: [String]?
        public var bumpCurrentVersion: Template
        public var createHotfixVersion: Template
        public var deployTagNameMatch: Criteria
        public var releaseBranchNameMatch: Criteria
        public var releaseNoteMatch: Criteria?
      }
      public struct DeployTag: Decodable {
        public var createName: Template
        public var parseBuild: Template
        public var parseVersion: Template
        public var createAnnotation: Template
      }
      public struct ReleaseBranch: Decodable {
        public var createName: Template
        public var parseVersion: Template
      }
      public struct AccessoryBranch: Decodable {
        public var mainatiners: [String]?
        public var nameMatch: Criteria
        public var createName: Template
        public var adjustVersion: Template
      }
      public struct Build: Decodable {
        public var build: String
        public var sha: String
        public var branch: String?
        public var review: UInt?
        public var target: String?
        public var product: String?
        public var version: String?
      }
    }
    public struct Requisition: Decodable {
      public var pkcs12: String
      public var password: Secret
      public var provisions: [String]
    }
    public struct Fusion: Decodable {
      public var resolution: Resolution?
      public var replication: Replication?
      public var integration: Integration?
      public struct Resolution: Decodable {
        public var createCommitMessage: Template
        public var rules: [Rule]
        public struct Rule: Decodable {
          public var title: Criteria?
          public var source: Criteria
        }
      }
      public struct Replication: Decodable {
        public var target: String
        public var prefix: String
        public var source: Criteria
        public var createCommitMessage: Template
      }
      public struct Integration: Decodable {
        public var mainatiners: [String]?
        public var rules: [Rule]
        public var prefix: String
        public var createCommitMessage: Template
        public var exportTargets: Template
        public struct Rule: Decodable {
          public var mainatiners: [String]?
          public var source: Criteria
          public var target: Criteria
        }
      }
    }
    public struct GitlabCi: Decodable {
      public var bot: Bot
      public var trigger: Trigger
      public struct Bot: Decodable {
        public var login: String
        public var apiToken: Secret?
        public var pushToken: Secret?
      }
      public struct Trigger: Decodable {
        public var job: String
        public var name: String
        public var profile: String
        public var pipeline: String
      }
    }
    public struct AwardApproval: Decodable {
      public var userActivity: Asset
      public var holdAward: String
      public var sanity: String
      public var groups: [String: Group]
      public var emergency: String?
      public var sourceBranch: [String: Criteria]?
      public var targetBranch: [String: Criteria]?
      public var personal: [String: [String]]?
      public struct Group: Decodable {
        public var award: String
        public var quorum: Int
        public var reserve: [String]?
        public var optional: [String]?
        public var required: [String]?
      }
    }
    public struct Communication: Decodable {
      public var slackHooks: [String: Secret]
      public var slackHookTextMessages: [SlackHookTextMessage]?
      public struct SlackHookTextMessage: Decodable {
        public var hook: String
        public var createMessageText: Template
        public var events: [String]
        public var userName: String?
        public var channel: String?
        public var emojiIcon: String?
      }
    }
  }
  public struct Asset: Decodable {
    public var path: String
    public var branch: String
    public var createCommitMessage: Template?
  }
  public struct Secret: Decodable {
    public var value: String?
    public var envVar: String?
    public var envFile: String?
  }
  public struct Criteria: Decodable {
    var include: [String]?
    var exclude: [String]?
  }
  public struct Template: Decodable {
    public var name: String?
    public var value: String?
  }
  public struct Decode: Query {
    public var content: String
    public init(content: String) {
      self.content = content
    }
    public typealias Reply = AnyCodable
  }
}
