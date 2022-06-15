import Foundation
import Facility
import FacilityAutomates
public struct SendReport: Query {
  public var cfg: Configuration
  public var report: Report
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
