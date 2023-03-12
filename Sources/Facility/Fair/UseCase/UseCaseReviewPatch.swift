import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewPatch: ReviewContractPerformer {
    var skip: Bool
    var args: [String]
    var patch: Data?
  }
}
