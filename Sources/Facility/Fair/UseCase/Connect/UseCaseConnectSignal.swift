import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ConnectSignal: ContractPerformer {
    var event: String
    var args: [String]
    var stdin: AnyCodable?
    static var triggerContract: Bool { true }
  }
}
