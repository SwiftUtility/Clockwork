import Foundation
import Facility
import FacilityQueries
import FacilityAutomates
public struct Requisitor {
  public init() {}
  public func importProvisions(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func importKeychains(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func importRequisites(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func reportExpiringRequisites(
    cfg: Configuration,
    days: UInt
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
}
