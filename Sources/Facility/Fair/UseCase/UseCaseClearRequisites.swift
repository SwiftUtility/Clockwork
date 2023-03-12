import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ClearRequisites: Performer {
    func perform(repo ctx: ContextRepo) throws -> Bool {
      try ctx.deleteProvisions()
      try ctx.deleteKeychain(requisition: ctx.parseRequisition())
      return true
    }
  }
}
