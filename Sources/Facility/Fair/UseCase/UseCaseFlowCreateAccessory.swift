import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowCreateAccessory: ProtectedContractPerformer {
    var name: String
    var commit: String
  }
}
