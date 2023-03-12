import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewList: ProtectedContractPerformer {
    var user: String
    var own: Bool
  }
}
