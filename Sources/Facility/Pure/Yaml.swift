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
    public var obsolescence: Criteria?
  }
  public struct Gitlab: Decodable {
    public var token: Secret
    public var users: Asset
    public var trigger: Trigger
    public struct Trigger: Decodable {
      public var jobId: String
      public var jobName: String
      public var profile: String
      public var pipeline: String
    }
    public struct User: Decodable {
      public var active: Bool
      public var watchTeams: Set<String>?
      public var watchAuthors: Set<String>?
    }
  }
  public struct Jira: Decodable {
    public var url: Secret
    public var rest: Secret
    public var token: Secret
    public var issues: [String: Signal]?
    public struct Signal: Decodable {
      public var url: Template
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
    public var builds: Builds?
    public var versions: Versions
    public var exportVersions: Template
    public var matchReleaseNote: Criteria
    public var createTagName: Template
    public var createTagAnnotation: Template
    public var createReleaseBranchName: Template
    public struct Builds: Decodable {
      public var storage: Asset
      public var maxBuildsCount: Int
      public var bump: Template
      public struct Storage: Decodable {
        public var next: String
        public var reserved: [String: Build]?
        public struct Build: Decodable {
          public var commit: String
          public var tag: String?
          public var review: UInt?
          public var target: String?
          public var branch: String?
        }
      }
    }
    public struct Versions: Decodable {
      public var storage: Asset
      public var maxReleasesCount: Int
      public var bump: Template
      public struct Storage: Decodable {
        public var products: [String: Product]?
        public var accessories: [String: Accessory]?
        public struct Product: Decodable {
          public var next: String
          public var stages: [String: Stage]?
          public var releases: [String: Release]?
        }
        public struct Release: Decodable {
          public var start: String
          public var branch: String
          public var deploys: [String]?
        }
        public struct Stage: Decodable {
          public var version: String
          public var build: String
          public var review: UInt?
          public var target: String
          public var branch: String
        }
        public struct Accessory: Decodable {
          public var versions: [String: String]?
        }
      }
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
  public struct Review: Decodable {
    public var storage: Asset
    public var queue: Asset
    public var approval: Approval
    public var replication: Replication
    public var integration: Integration
    public var propositions: [String: Proposition]
    public var createCommitMessage: Template
    public var exportMergeTargets: Template
    public struct Storage: Decodable {
      public var queues: [String: [UInt]]
      public var states: [String: State]
      public struct State: Decodable {
        public var target: String
        public var authors: [String]
        public var status: Status?
        public var skip: [String]?
        public var teams: [String]?
        public var emergent: String?
        public var verified: String?
        public var randoms: [String]?
        public var legates: [String]?
        public var replicate: String?
        public var integrate: String?
        public var reviewers: [String: Reviewer]?
      }
      public struct Reviewer: Decodable {
        public var comments: Int?
        public var commit: String?
        public var resolution: Resolution?
      }
      public enum Resolution: String, Decodable {
        case fragil
        case advance
        case obsolete
      }
      public enum Status: String, Decodable {
        case queued
        case wanted
        case blocked
        case stopped
      }
    }
    public struct Proposition: Decodable {
      public var source: Criteria
      public var title: Criteria?
      public var task: String?
    }
    public struct Replication: Decodable {
      public var autoApproveFork: Bool?
      public var allowOrphaned: Bool?
    }
    public struct Integration: Decodable {
      public var autoApproveFork: Bool?
      public var allowOrphaned: Bool?
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
        public var state: State = .normal
        public var skip: [String]?
        public var teams: [String]?
        public var emergent: String?
        public var verified: String?
        public var randoms: [String]?
        public var legates: [String]?
        public var replicate: String?
        public var integrate: String?
        public var approves: [String: [String: String]]?
        public enum State: String, Decodable {
          case blocked
          case stopped
          case normal
        }
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
