import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowExportVersions: Performer {
    var product: String
    func perform(repo ctx: ContextLocal) throws -> Bool {
      #warning("TBD")
      return true
    }
  }
}
