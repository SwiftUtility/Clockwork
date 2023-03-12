import Foundation
import Facility
import FacilityPure
public extension UseCase {
  struct ClearRequisites: Performer {
    public static func make() -> Self { .init() }
    public func perform(repo ctx: ContextRepo) throws -> Bool {
      try ctx.deleteProvisions()
      try ctx.deleteKeychain(requisition: ctx.parseRequisition())
      return true
    }
  }
}
