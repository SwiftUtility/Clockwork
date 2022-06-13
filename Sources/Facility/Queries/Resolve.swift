import Foundation
import Facility
import FacilityAutomates
public struct SendReport: Query {
  public var cfg: Configuration
  public var report: Report
//  public init(cfg: Configuration, report: Report) {
//    self.cfg = cfg
//    self.report = report
//  }
//  public static func make(cfg: Configuration, reports: [Report]) -> [Self] {
//    reports.reduce(into: []) { $0.append(.init(cfg: cfg, report: $1)) }
//  }
  public typealias Reply = Void
}
public extension Configuration {
  func makeSendReport(report: Report) -> SendReport { .init(
    cfg: self,
    report: report
  )}
}
public struct LogMessage: Query {
  public var message: String
  public init(message: String) { self.message = message }
  public typealias Reply = Void
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
