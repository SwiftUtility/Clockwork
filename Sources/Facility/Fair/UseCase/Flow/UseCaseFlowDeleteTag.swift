import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowDeleteTag: ProtectedContractPerformer {
    var name: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      #warning("TBD")
    }
  }
}
