import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewLabels: ReviewContractPerformer {
    var labels: [String]
    var add: Bool
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
