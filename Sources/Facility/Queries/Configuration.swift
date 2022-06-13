import Foundation
import Facility
import FacilityAutomates
public struct ResolveProfile: Query {
  public var git: Git
  public var file: Git.File
  public init(git: Git, file: Git.File) {
    self.git = git
    self.file = file
  }
  public typealias Reply = Configuration.Profile
}
public struct ResolveCodeOwnage: Query {
  public var cfg: Configuration
  public var profile: Configuration.Profile
  public init(cfg: Configuration, profile: Configuration.Profile) {
    self.cfg = cfg
    self.profile = profile
  }
  public typealias Reply = [String: Criteria]
}
public struct ResolveFileTaboos: Query {
  public var cfg: Configuration
  public var profile: Configuration.Profile
  public init(cfg: Configuration, profile: Configuration.Profile) {
    self.cfg = cfg
    self.profile = profile
  }
  public typealias Reply = [FileTaboo]
}
public struct ResolveAwardApproval: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) {
    self.cfg = cfg
  }
  public typealias Reply = AwardApproval
}
public struct ResolveAwardApprovalUserActivity: Query {
  public var cfg: Configuration
  public var awardApproval: AwardApproval
  public init(cfg: Configuration, awardApproval: AwardApproval) {
    self.cfg = cfg
    self.awardApproval = awardApproval
  }
  public typealias Reply = [String: Bool]
}
public struct ResolveFlow: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) {
    self.cfg = cfg
  }
  public typealias Reply = Flow
}
public struct ResolveProduction: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) {
    self.cfg = cfg
  }
  public typealias Reply = Production
}
public struct ResolveProductionBuilds: Query {
  public var cfg: Configuration
  public var production: Production
  public init(cfg: Configuration, production: Production) {
    self.cfg = cfg
    self.production = production
  }
  public typealias Reply = [Yaml.Controls.Production.Build]
}
public struct ResolveProductionVersions: Query {
  public var cfg: Configuration
  public var production: Production
  public init(cfg: Configuration, production: Production) {
    self.cfg = cfg
    self.production = production
  }
  public typealias Reply = [String: String]
}
