import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ReviewApprove: ReviewContractPerformer {
    var advance: Bool
    static func reviewApprove(
      advance: Bool
    ) -> Performer {
      ReviewApprove(advance: advance)
    }
  }
}
