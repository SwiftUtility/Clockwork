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
public struct ResolveRequisition: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) {
    self.cfg = cfg
  }
  public typealias Reply = Requisition
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
public struct PersistBuilds: Query {
  public var cfg: Configuration
  public var pushUrl: String
  public var production: Production
  public var builds: [Yaml.Controls.Production.Build]
  public var build: Yaml.Controls.Production.Build
  public init(
    cfg: Configuration,
    pushUrl: String,
    production: Production,
    builds: [Yaml.Controls.Production.Build],
    build: Yaml.Controls.Production.Build
  ) {
    self.cfg = cfg
    self.pushUrl = pushUrl
    self.production = production
    self.builds = builds
    self.build = build
  }
  public typealias Reply = Void
}
public struct PersistVersions: Query {
  public var cfg: Configuration
  public var pushUrl: String
  public var production: Production
  public var versions: [String: String]
  public var product: Production.Product
  public var version: String
  public init(
    cfg: Configuration,
    pushUrl: String,
    production: Production,
    versions: [String: String],
    product: Production.Product,
    version: String
  ) {
    self.cfg = cfg
    self.pushUrl = pushUrl
    self.production = production
    self.versions = versions
    self.product = product
    self.version = version
  }
  public typealias Reply = Void
}
public struct PersistUserActivity: Query {
  public var cfg: Configuration
  public var pushUrl: String
  public var awardApproval: AwardApproval
  public var userActivity: [String: Bool]
  public var user: String
  public var active: Bool
  public init(
    cfg: Configuration,
    pushUrl: String,
    awardApproval: AwardApproval,
    userActivity: [String: Bool],
    user: String,
    active: Bool
  ) {
    self.cfg = cfg
    self.pushUrl = pushUrl
    self.awardApproval = awardApproval
    self.userActivity = userActivity
    self.user = user
    self.active = active
  }
  public typealias Reply = Void
}
