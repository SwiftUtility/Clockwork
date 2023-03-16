import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowCreateDeploy: ProtectedContractPerformer {
    var branch: String
    var commit: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
