import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewEnqueue: ReviewContractPerformer {
    var jobs: [String]
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
