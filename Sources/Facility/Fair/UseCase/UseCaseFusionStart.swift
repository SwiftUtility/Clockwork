import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FusionStart: ProtectedContractPerformer {
    var fork: String
    var target: String
    var source: String
    var prefix: Review.Fusion.Prefix
  }
}
