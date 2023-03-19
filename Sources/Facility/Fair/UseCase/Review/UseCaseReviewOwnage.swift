import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewOwnage: ContractPerformer {
    var user: String
    var iid: UInt
    var own: Bool
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
