import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct UserActivity: ProtectedContractPerformer {
    var login: String
    var active: Bool
  }
}
