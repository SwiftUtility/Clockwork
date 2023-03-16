import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewOwnage: ContractPerformer {
    var user: String
    var iid: UInt
    var own: Bool
    static var triggerContract: Bool { true }
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
