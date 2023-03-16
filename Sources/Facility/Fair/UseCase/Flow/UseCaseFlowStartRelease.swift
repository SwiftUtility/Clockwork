import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowStartRelease: ProtectedContractPerformer {
    var product: String
    var commit: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
