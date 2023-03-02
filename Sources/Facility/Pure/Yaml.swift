import Foundation
import Facility
public enum Yaml {
  public struct Profile: Decodable {
    public var gitlab: String?
    public var slack: String?
    public var rocket: String?
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
    public var apiToken: Secret
    public var deployKey: String
    public var storage: Asset
    public var trigger: Trigger
    public var review: Template?
    public var notes: [String: Note]?
    public struct Note: Decodable {
      public var text: Template
      public var events: [String]
    }
    public struct Trigger: Decodable {
      public var jobId: String
      public var jobName: String
      public var pipeline: String
    }
    public struct Storage: Decodable {
      public var bots: [String]
      public var users: [String: User]
      public var reviews: [String: UInt]?
      public struct User: Decodable {
        public var active: Bool
        public var watchTeams: Set<String>?
        public var watchAuthors: Set<String>?
      }
    }
  }
  public struct Jira: Decodable {
    public var url: Secret
    public var token: Secret
    public var issue: String
    public var chains: [String: Chain]?
    public struct Chain: Decodable {
      public var links: [Link]
      public var events: [String]
      public struct Link: Decodable {
        public var url: Template
        public var body: Template?
        public var method: String?
      }
    }
  }
  public enum Chat {
    public struct Storage: Decodable {
      public var users: [String: String]?
      public var channels: [String: String]?
      public var mentions: [String: String]?
      public var tags: [String: [String: Thread]]?
      public var issues: [String: [String: Thread]]?
      public var reviews: [String: [String: Thread]]?
      public var branches: [String: [String: Thread]]?
      public struct Thread: Decodable {
        public var channel: String
        public var message: String
      }
    }
    public struct Diffusion: Decodable {
      public var signals: [String: Signal]?
      public var directs: [String: Signal]?
      public var tags: [String: Thread]?
      public var issues: [String: Thread]?
      public var reviews: [String: Thread]?
      public var branches: [String: Thread]?
      public struct Signal: Decodable {
        public var path: String
        public var body: Template
        public var method: String?
        public var events: [String]
      }
      public struct Thread: Decodable {
        public var create: Signal
        public var update: [String: Signal]?
      }
    }
    public struct Rocket: Decodable {
      public var url: Secret
      public var user: Secret
      public var token: Secret
      public var storage: Asset
      public var diffusion: Diffusion
    }
    public struct Slack: Decodable {
      public var url: Secret
      public var token: Secret
      public var storage: Asset
      public var diffusion: Diffusion
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
    public var storage: Asset
    public var buildCount: Int
    public var releaseCount: Int
    public var bumpBuild: Template
    public var bumpVersion: Template
    public var exportVersions: Template
    public var matchReleaseNote: Criteria
    public var createTagName: Template
    public var createTagAnnotation: Template
    public var createReleaseBranchName: Template
    public struct Storage: Decodable {
      public var stages: [String: Stage]
      public var deploys: [String: Deploy]
      public var families: [String: Family]
      public var products: [String: Product]
      public var releases: [String: Release]
      public var accessories: [String: [String: String]?]
      public struct Family: Decodable {
        public var nextBuild: String
        public var prevBuilds: [String: Build]?
      }
      public struct Build: Decodable {
        public var commit: String
        public var branch: String
        public var review: UInt?
      }
      public struct Product: Decodable {
        public var family: String
        public var nextVersion: String
        public var prevVersions: [String]?
      }
      public struct Release: Decodable {
        public var commit: String
        public var product: String
        public var version: String
      }
      public struct Stage: Decodable {
        public var product: String
        public var version: String
        public var build: String
        public var branch: String
        public var review: UInt?
      }
      public struct Deploy: Decodable {
        public var product: String
        public var version: String
        public var build: String
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
    public var rules: Secret
    public var storage: Asset
    public var exportFusion: Template
    public var createMergeTitle: Template
    public var createMergeCommit: Template
    public var createSquashCommit: Template
    public var replication: Replication
    public var duplication: Duplication
    public var integration: Integration
    public var propogation: Propogation
    public var propositions: [String: Proposition]
    public struct Rules: Decodable {
      public var hold: String
      public var baseWeight: Int
      public var sanity: String?
      public var weights: [String: Int]?
      public var teams: [String: Team]?
      public var randoms: [String: Set<String>]?
      public var authorship: [String: Set<String>]?
      public var ignore: [String: Set<String>]?
      public var sourceBranch: [String: Criteria]?
      public var targetBranch: [String: Criteria]?
      #warning("TBD implement labels")
      public var labels: Labels?
      public struct Team: Decodable {
        public var quorum: Int
        public var advance: Bool?
        public var random: [String]?
        public var reserve: [String]?
        public var optional: [String]?
        public var required: [String]?
      }
      public struct Labels: Decodable {
        public var emergent: String?
        public var team: [String: [String]]?
        public var phase: [String: [String]]?
        public var merge: [String: [String]]?
        public var squash: [String: [String]]?
      }
    }
    public struct Storage: Decodable {
      public var queues: [String: [UInt]]
      public var states: [String: State]
      public struct State: Decodable {
        public var source: String
        public var target: String
        public var fusion: String?
        public var authors: [String]?
        public var phase: Phase?
        public var skip: [String]?
        public var teams: [String]?
        public var emergent: String?
        public var verified: String?
        public var randoms: [String]?
        public var legates: [String]?
        public var approves: [String: [String: String]]?
      }
      public enum Resolution: String, Decodable {
        case fragil
        case advance
        case obsolete
      }
      public enum Phase: String, Decodable {
        case block
        case stuck
        case amend
        case ready
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
    public struct Duplication: Decodable {
      public var autoApproveFork: Bool?
      public var allowOrphaned: Bool?
    }
    public struct Integration: Decodable {
      public var autoApproveFork: Bool?
      public var allowOrphaned: Bool?
    }
    public struct Propogation: Decodable {
      public var autoApproveFork: Bool?
      public var allowOrphaned: Bool?
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
