import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct UserWatchTeams: ProtectedContractPerformer {
    var login: String
    var watch: [String]
    var add: Bool
  }
}
