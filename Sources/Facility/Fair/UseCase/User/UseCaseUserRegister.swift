import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct UserRegister: ProtectedContractPerformer {
    var login: String
    var slack: String
    var rocket: String
  }
}
