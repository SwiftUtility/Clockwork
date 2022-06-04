import Foundation
import Facility
import FacilityQueries
import FacilityAutomates
public struct Requisitor {
  public init() {}
  public func installProvisions(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func installKeychains(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func installRequisites(
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
