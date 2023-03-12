import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowChangeNext: ProtectedContractPerformer {
    var product: String
    var version: String
  }
}
