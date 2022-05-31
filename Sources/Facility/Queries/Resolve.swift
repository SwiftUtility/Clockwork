import Foundation
import Facility
import FacilityAutomates
public struct ValidateUnownedCode: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) { self.cfg = cfg }
  public typealias Reply = Bool
}
public struct ValidateFileRules: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) { self.cfg = cfg }
  public typealias Reply = Bool
}
public struct ValidateReviewTitle: Query {
  public var cfg: Configuration
  public var title: String
  public init(cfg: Configuration, title: String) {
    self.cfg = cfg
    self.title = title
  }
  public typealias Reply = Bool
}
public struct ValidateReviewObsolete: Query {
  public var cfg: Configuration
  public var target: String
  public init(cfg: Configuration, target: String) {
    self.cfg = cfg
    self.target = target
  }
  public typealias Reply = Bool
}
public struct ValidateReviewConflictMarkers: Query {
  public var cfg: Configuration
  public var target: String
  public init(cfg: Configuration, target: String) {
    self.cfg = cfg
    self.target = target
  }
  public typealias Reply = Bool
}
public struct ValidateReplicationDiff: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) { self.cfg = cfg }
  public typealias Reply = Bool
}
public struct ValidateReplicationCommits: Query {
  public var cfg: Configuration
  public init(cfg: Configuration) { self.cfg = cfg }
  public typealias Reply = Bool
}
public struct SendReport: Query {
  public var cfg: Configuration
  public var report: Report
  public init(cfg: Configuration, report: Report) {
    self.cfg = cfg
    self.report = report
  }
  public static func make(cfg: Configuration, reports: [Report]) -> [Self] {
    reports.reduce(into: []) { $0.append(.init(cfg: cfg, report: $1)) }
  }
  public typealias Reply = Void
}
public struct LogMessage: Query {
  public var message: String
  public init(message: String) { self.message = message }
  public typealias Reply = Void
}
public extension Configuration {
  func makeSendReport(report: Report) -> SendReport { .init(
    cfg: self,
    report: report
  )}
}
