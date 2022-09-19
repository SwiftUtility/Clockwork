import Foundation
import Facility
public enum Yaml {
  public struct Profile: Decodable {
    public var gitlabCi: GitlabCi?
    public var slack: Slack?
    public var codeOwnage: String?
    public var fileTaboos: String?
    public var cocoapods: String?
    public var templates: String?
    public var production: String?
    public var requisition: String?
    public var fusion: String?
    public var context: Preset?
  }
  public struct GitlabCi: Decodable {
    public var token: Secret
    public var trigger: Trigger
    public struct Trigger: Decodable {
      public var jobId: String
      public var jobName: String
      public var profile: String
      public var pipeline: String
    }
  }
  public struct Slack: Decodable {
    public var token: Secret
    public var signals: String
    public struct Signal: Decodable {
      public var method: String
      public var body: Template
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
  public struct Production: Decodable {
    public var builds: Asset
    public var versions: Asset
    public var releases: Asset
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
      public var createThread: Template
      public var createName: Template
      public var parseVersion: Template
    }
    public struct AccessoryBranch: Decodable {
      public var nameMatch: Criteria
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
    public struct Release: Decodable {
      public var thread: Thread
      public var product: String
      public var version: String
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
    public var queue: Asset
    public var approval: Approval
    public var createThread: Template
    public var proposition: Proposition
    public var replication: Replication
    public var integration: Integration
    public var createMergeCommitMessage: Template
    public struct Proposition: Decodable {
      public var createCommitMessage: Template
      public var rules: [Rule]
      public struct Rule: Decodable {
        public var title: Criteria
        public var source: Criteria
        public var task: String?
      }
    }
    public struct Replication: Decodable {
      public var createCommitMessage: Template
    }
    public struct Integration: Decodable {
      public var createCommitMessage: Template
      public var exportAvailableTargets: Template
    }
    public struct Approval: Decodable {
      public var sanity: String
      public var rules: Preset
      public var statuses: Asset
      public var approvers: Asset
      public var antagonists: Secret?
      public struct Rules: Decodable {
        public var emergency: String?
        public var randoms: Randoms?
        public var teams: [String: Team]?
        public var authorship: [String: [String]]?
        public var sourceBranch: [String: Criteria]?
        public var targetBranch: [String: Criteria]?
        public struct Team: Decodable {
          public var quorum: Int
          public var advanceApproval: Bool?
          public var selfApproval: Bool?
          public var ignoreAntagonism: Bool?
          public var labels: [String]?
          public var reserve: [String]?
          public var optional: [String]?
          public var required: [String]?
        }
        public struct Randoms: Decodable {
          public var minQuorum: Int
          public var maxQuorum: Int
          public var baseWeight: Int
          public var weights: [String: Int]?
          public var advanceApproval: Bool
        }
      }
      public struct Status: Decodable {
        public var thread: Thread
        public var target: String
        public var authors: [String]
        public var review: Review?
        public struct Review: Decodable {
          public var randoms: [String]
          public var teams: [String: [String]]
          public var approves: [String: Approve]
          public struct Approve: Decodable {
            public var commit: String
            public var resolution: Resolution
            public enum Resolution: String, Decodable {
              case block
              case fragil
              case advance
              case emergent
            }
          }
        }
      }
      public struct Approver: Decodable {
        public var active: Bool
        public var slack: String
        public var name: String
      }
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
  public struct Thread: Codable {
    public var channel: String
    public var ts: String
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
