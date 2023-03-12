import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowStartHotfix: ProtectedContractPerformer {
    var product: String
    var commit: String
    var version: String
  }
}
