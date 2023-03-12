import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowCreateDeploy: ProtectedContractPerformer {
    var branch: String
    var commit: String
    static func flowCreateDeploy(
      branch: String,
      commit: String
    ) -> Performer {
      FlowCreateDeploy(branch: branch, commit: commit)
    }
  }
}
