import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct RequisitesClear: Performer {
    func perform(repo ctx: ContextLocal) throws -> Bool {
      try ctx.sh.sysDelete(path: .provisions)
      try ctx.sh.sysCreateDir(path: .provisions)
      let requisition = try ctx.parseRequisition()
      try ctx.sh.securityDelete(keychain: requisition.keychain.name)
      return true
    }
  }
}
