import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewSkip: ProtectedContractPerformer {
    var iid: UInt
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
