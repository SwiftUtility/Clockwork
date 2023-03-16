import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewApprove: ReviewContractPerformer {
    var advance: Bool
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
