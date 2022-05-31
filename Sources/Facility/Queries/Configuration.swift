import Foundation
import Facility
import FacilityAutomates
public struct ResolveConfiguration: Query {
  public var profile: String
  public var verbose: Bool
  public var env: [String: String]
  public init(
    profile: String,
    verbose: Bool,
    env: [String: String]
  ) {
    self.profile = profile
    self.verbose = verbose
    self.env = env
  }
  public typealias Reply = Configuration
}
public struct ResolveProfile: Query {
  public var git: Git
  public var file: Git.File
  public init(git: Git, file: Git.File) {
    self.git = git
    self.file = file
  }
  public typealias Reply = Configuration.Profile
}
public struct ResolveFileApproval: Query {
  public var cfg: Configuration
  public var profile: Configuration.Profile?
  public init(cfg: Configuration, profile: Configuration.Profile?) {
    self.cfg = cfg
    self.profile = profile
  }
  public typealias Reply = [String: Criteria]?
}
public struct ResolveFileRules: Query {
  public var cfg: Configuration
  public var profile: Configuration.Profile?
  public init(cfg: Configuration, profile: Configuration.Profile?) {
    self.cfg = cfg
    self.profile = profile
  }
  public typealias Reply = [FileRule]?
}
public struct ResolveApproval: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) {
    self.cfg = cfg
  }
  public typealias Reply = AwardApproval?
}
public struct ResolveVacationers: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) {
    self.cfg = cfg
  }
  public typealias Reply = Set<String>?
}
public struct ResolveGitlab: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) {
    self.cfg = cfg
  }
  public typealias Reply = Gitlab
}
