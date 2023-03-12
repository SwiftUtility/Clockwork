import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowChangeAccessory: ProtectedContractPerformer {
    var product: String
    var branch: String
    var version: String
  }
}
