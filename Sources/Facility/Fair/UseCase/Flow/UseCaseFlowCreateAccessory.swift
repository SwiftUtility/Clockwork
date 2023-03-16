import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowCreateAccessory: ProtectedContractPerformer {
    var name: String
    var commit: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
