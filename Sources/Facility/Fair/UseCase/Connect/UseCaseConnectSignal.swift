import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ConnectSignal: ContractPerformer {
    var event: String
    var args: [String]
    var stdin: AnyCodable?
    mutating func perform(exclusive ctx: ContextExclusive) throws {
#warning("TBD")
    }
    static var triggerContract: Bool { true }
  }
}
