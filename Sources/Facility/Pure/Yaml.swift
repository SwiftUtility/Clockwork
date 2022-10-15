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
    public var context: Secret?
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
      public var next: AlphaNumeric
      public var deliveries: [AlphaNumeric: Delivery]?
      public var accessories: [String: AlphaNumeric]?
      public struct Delivery: Decodable {
        public var thread: Thread
        public var deploys: [String]?
      }
    }
    public typealias Builds = [AlphaNumeric: Build]
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
      public var rules: Secret
      public var statuses: Asset
      public var approvers: Asset
      public var haters: Secret?
      public struct Rules: Decodable {
        public var sanity: String?
        public var randoms: Randoms
        public var teams: [String: Team]?
        public var authorship: [String: [String]]?
        public var sourceBranch: [String: Criteria]?
        public var targetBranch: [String: Criteria]?
        public struct Team: Decodable {
          public var quorum: Int
          public var advanceApproval: Bool?
          public var labels: [String]?
          public var mentions: [String]?
          public var reserve: [String]?
          public var optional: [String]?
          public var required: [String]?
        }
        public struct Randoms: Decodable {
          public var quorum: Int
          public var baseWeight: Int
          public var weights: [String: Int]?
          public var advanceApproval: Bool
        }
      }
      public struct Status: Decodable {
        public var thread: Thread
        public var target: String
        public var authors: [String]
        public var randoms: Set<String>
        public var participants: Set<String>
        public var teams: Set<String>
        public var approves: [String: [String: Resolution]]
        public var verification: String?
        public var emergent: Bool
        public enum Resolution: String, Decodable {
          case block
          case fragil
          case advance
          case outdated
          public var approved: Bool {
            switch self {
            case .fragil, .advance: return true
            case .block, .outdated: return false
            }
          }
          public var fragil: Bool {
            switch self {
            case .fragil: return true
            default: return false
            }
          }
          public var block: Bool {
            switch self {
            case .block: return true
            default: return false
            }
          }
          public var outdated: Bool {
            switch self {
            case .outdated: return true
            default: return false
            }
          }
        }
      }
      public struct Approver: Decodable {
        public var active: Bool
        public var slack: String
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
  public struct Thread: Decodable {
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
