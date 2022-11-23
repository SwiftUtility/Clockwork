import Foundation
import Facility
public enum Yaml {
  public struct Profile: Decodable {
    public var gitlab: String?
    public var slack: String?
    public var jira: String?
    public var codeOwnage: String?
    public var fileTaboos: String?
    public var cocoapods: String?
    public var templates: String?
    public var flow: String?
    public var requisites: String?
    public var review: String?
  }
  public struct Gitlab: Decodable {
    public var token: Secret
    public var trigger: Trigger
    public struct Trigger: Decodable {
      public var jobId: String
      public var jobName: String
      public var profile: String
      public var pipeline: String
    }
  }
  public struct Jira: Decodable {
    public var url: Secret
    public var api: Secret?
    public var login: Secret?
    public var password: Secret?
    public var issues: [String: Signal]?
    public struct Signal: Decodable {
      public var http: String?
      public var path: String?
      public var body: Template
      public var events: [String]
    }
  }
  public struct Slack: Decodable {
    public var token: Secret
    public var storage: Asset
    public var signals: [String: Signal]?
    public var directs: [String: Signal]?
    public var jira: Jira?
    public var gitlab: Gitlab?
    public struct Gitlab: Decodable {
      public var storage: Asset
      public var tags: [String: Thread]?
      public var reviews: [String: Thread]?
      public var branches: [String: Thread]?
      public struct Storage: Decodable {
        public var tags: [String: [String: Thread.Storage]]?
        public var reviews: [String: [String: Thread.Storage]]?
        public var branches: [String: [String: Thread.Storage]]?
      }
    }
    public struct Jira: Decodable {
      public var storage: Asset
      public var epics: [String: Thread]?
      public var issues: [String: Thread]?
      public struct Storage: Decodable {
        public var epics: [String: [String: Thread.Storage]]?
        public var issues: [String: [String: Thread.Storage]]?
      }
    }
    public struct Thread: Decodable {
      public var create: Signal
      public var update: [String: Signal]?
      public struct Storage: Decodable {
        public var channel: String
        public var message: String
      }
    }
    public struct Signal: Decodable {
      public var method: String?
      public var body: Template
      public var events: [String]
    }
    public struct Storage: Decodable {
      public var users: [String: User]?
      public var channels: [String: Channel]?
      public var mentions: [String: Mention]?
      public struct User: Decodable {
        public var id: String
        public var subscribe: [String]?
      }
      public struct Channel: Decodable {
        public var id: String
      }
      public struct Mention: Decodable {
        public var subteams: [String]?
        public var users: [String]?
      }
    }
  }
  public struct FileTaboo: Decodable {
    public var rule: String
    public var file: Criteria?
    public var line: Criteria?
  }
  public struct Cocoapods: Decodable {
    public var specs: [Spec]?
    public struct Spec: Decodable {
      public var name: String
      public var url: String
      public var sha: String
    }
  }
  public struct Flow: Decodable {
    public var builds: Asset
    public var versions: Asset
    public var buildsCount: Int
    public var releasesCount: Int
    public var bumpBuildNumber: Template
    public var exportBuilds: Template
    public var exportVersions: Template
    public var matchReleaseNote: Criteria
    public var matchAccessoryBranch: Criteria
    public var products: [String: Product]
    public struct Product: Decodable {
      public var matchStageTag: Criteria
      public var matchDeployTag: Criteria
      public var matchReleaseBranch: Criteria
      public var parseTagBuild: Template
      public var parseTagVersion: Template
      public var parseBranchVersion: Template
      public var bumpReleaseVersion: Template
      public var createTagName: Template
      public var createTagAnnotation: Template
      public var createReleaseThread: Template
      public var createReleaseBranchName: Template
    }
    public struct Build: Decodable {
      public var sha: String
      public var tag: String?
      public var branch: String?
      public var review: UInt?
      public var target: String?
    }
    public struct Version: Decodable {
      public var next: String
      public var deliveries: [String: Delivery]?
      public var accessories: [String: String]?
      public struct Delivery: Decodable {
        public var deploys: [String]?
      }
    }
    public typealias Versions = [String: Version]
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
  public struct Review: Decodable {
    public var queue: Asset
    public var approval: Approval
    public var replication: Replication
    public var integration: Integration
    public var propositions: [String: Proposition]
    public var createCommitMessage: Template
    public struct Proposition: Decodable {
      public var createCommitMessage: Template
      public var source: Criteria
      public var title: Criteria?
      public var jiraIssue: String?
    }
    public struct Replication: Decodable {
      public var createCommitMessage: Template
      public var autoApproveFork: Bool?
    }
    public struct Integration: Decodable {
      public var createCommitMessage: Template
      public var exportTargets: Template
      public var autoApproveFork: Bool?
    }
    public struct Approval: Decodable {
      public var rules: Secret
      public var statuses: Asset
      public var approvers: Asset
      public var haters: Secret?
      public struct Rules: Decodable {
        public var sanity: String?
        public var weights: [String: Int]?
        public var baseWeight: Int
        public var teams: [String: Team]?
        public var randoms: [String: [String]]?
        public var authorship: [String: [String]]?
        public var sourceBranch: [String: Criteria]?
        public var targetBranch: [String: Criteria]?
        public struct Team: Decodable {
          public var quorum: Int
          public var advance: Bool?
          public var labels: [String]?
          public var random: [String]?
          public var reserve: [String]?
          public var optional: [String]?
          public var required: [String]?
        }
      }
      public struct Status: Decodable {
        public var target: String
        public var authors: [String]
        public var skip: [String]?
        public var teams: [String]?
        public var emergent: String?
        public var verified: String?
        public var blocked: Bool?
        public var randoms: [String]?
        public var legates: [String]?
        public var approves: [String: [String: String]]?
      }
      public struct Approver: Decodable {
        public var active: Bool
        public var watchTeams: Set<String>?
        public var watchAuthors: Set<String>?
      }
    }
  }
  public struct Asset: Decodable {
    public var path: String
    public var branch: String
    public var createCommitMessage: Template
  }
  public struct Secret: Decodable {
    public var value: String?
    public var envVar: String?
    public var envFile: String?
    public var sysFile: String?
    public var gitFile: GitFile?
    public struct GitFile: Decodable {
      public var path: String
      public var branch: String
    }
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
