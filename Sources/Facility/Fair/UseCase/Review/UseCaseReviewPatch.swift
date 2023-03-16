import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewPatch: ReviewContractPerformer {
    var skip: Bool
    var args: [String]
    var patch: Data?
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
