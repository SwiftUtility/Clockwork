import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct UserActivity: ProtectedContractPerformer {
    var login: String
    var active: Bool
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
