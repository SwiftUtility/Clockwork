import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct UserWatchAuthors: ProtectedContractPerformer {
    var login: String
    var watch: [String]
    var add: Bool
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
  }
}
