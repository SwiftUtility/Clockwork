import Foundation
import Facility
public enum Yaml {
  public struct Profile: Decodable {
    public var trigger: Trigger
    public var communication: Preset
    public var gitlabCi: Preset
    public var awardApproval: Preset?
    public var context: Preset?
    public var codeOwnage: String?
    public var fileTaboos: String?
    public var obsolescence: Criteria?
    public var cocoapods: String?
    public var templates: String?
    public var production: String?
    public var requisition: String?
    public var fusion: String?
    public var forbiddenCommits: Asset?
    public var userActivity: Asset?
    public var reviewQueue: Asset?
  }
  public struct Trigger: Decodable {
    public var job: String
    public var name: String
    public var profile: String
    public var pipeline: String
  }
  public struct Cocoapods: Decodable {
    public var specs: [Spec]?
    public struct Spec: Decodable {
      public var name: String
      public var url: String
      public var sha: String
    }
  }
  public struct FileTaboo: Decodable {
    public var rule: String
    public var file: Criteria?
    public var line: Criteria?
  }
  public struct Production: Decodable {
    public var builds: Asset
    public var versions: Asset
    public var bumpBuildNumber: Template
    public var exportBuild: Template
    public var exportVersions: Template
    public var deployTag: DeployTag
    public var releaseBranch: ReleaseBranch
    public var products: [String: Product]
    public var accessoryBranch: AccessoryBranch?
    public var maxBuildsCount: Int?
    public struct Product: Decodable {
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
    public var branch: String
    public var keychain: Keychain
    public var requisites: [String: Requisite]
    public struct Keychain: Decodable {
      public var name: String
      public var password: Secret
    }
    public struct Requisite: Decodable {
      public var pkcs12: String
      public var password: Secret
      public var provisions: [String]
    }
  }
  public struct Fusion: Decodable {
    public var createMergeCommitMessage: Template
    public var proposition: Proposition
    public var replication: Replication
    public var integration: Integration
    public var targets: Criteria
    public struct Proposition: Decodable {
      public var createCommitMessage: Template
      public var rules: [Rule]
      public struct Rule: Decodable {
        public var title: Criteria
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
      public var rules: [Rule]
      public var prefix: String
      public var createCommitMessage: Template
      public var exportAvailableTargets: Template
      public struct Rule: Decodable {
        public var source: Criteria
        public var target: Criteria
      }
    }
  }
  public struct GitlabCi: Decodable {
    public var botLogin: String
    public var apiToken: Secret?
    public var pushToken: Secret?
  }
  public struct AwardApproval: Decodable {
    public var holdAward: String
    public var statusLabel: String
    public var sourceBranch: [String: Criteria]?
    public var targetBranch: [String: Criteria]?
    public var sanity: String
    public var emergency: String?
    public var groups: [String: Group]
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
    public var templates: String?
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
  public struct Asset: Decodable {
    public var path: String
    public var branch: String
    public var createCommitMessage: Template
  }
  public struct Preset: Decodable {
    public var path: String
    public var branch: String
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
