import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewOwnage: ContractPerformer {
    var user: String
    var iid: UInt
    var own: Bool
  }
}
