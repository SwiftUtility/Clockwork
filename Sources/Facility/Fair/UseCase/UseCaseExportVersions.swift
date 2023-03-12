import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ExportVersions: Performer {
    var product: String
    func perform(repo ctx: ContextRepo) throws -> Bool {
      #warning("TBD")
      return true
    }
  }
}
