import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowChangeNext: ProtectedContractPerformer {
    var product: String
    var version: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      _ = try ctx.getFlow()
      try ctx.storage.flow.change(product: product, nextVersion: version)
    }
  }
}
