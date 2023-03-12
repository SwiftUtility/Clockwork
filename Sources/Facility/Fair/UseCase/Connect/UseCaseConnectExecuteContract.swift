import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ConnectExecuteContract: Performer {
    func perform(repo ctx: ContextLocal) throws -> Bool {
      try ctx.exclusive()
      #warning("TBD")
      return true
    }
  }
}
