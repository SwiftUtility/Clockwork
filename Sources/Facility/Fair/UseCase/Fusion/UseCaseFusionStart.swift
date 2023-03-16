import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FusionStart: ProtectedContractPerformer {
    var fork: String
    var target: String
    var source: String
    var prefix: Review.Fusion.Prefix
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
