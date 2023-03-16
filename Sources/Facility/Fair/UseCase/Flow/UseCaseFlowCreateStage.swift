import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowCreateStage: ProtectedContractPerformer {
    var product: String
    var build: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
