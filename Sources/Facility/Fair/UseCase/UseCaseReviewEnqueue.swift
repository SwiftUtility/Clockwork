import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewEnqueue: ReviewContractPerformer {
    var jobs: [String]
  }
}
