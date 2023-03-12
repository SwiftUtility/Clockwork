import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct RequisitesClear: Performer {
    func perform(repo ctx: ContextLocal) throws -> Bool {
      try ctx.deleteProvisions()
      try ctx.deleteKeychain(requisition: ctx.parseRequisition())
      return true
    }
  }
}
