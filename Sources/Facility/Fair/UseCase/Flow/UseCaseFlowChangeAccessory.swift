import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowChangeAccessory: ProtectedContractPerformer {
    var product: String
    var branch: String
    var version: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      let branch: Ctx.Git.Branch = try branch.isEmpty.not
        .then(.make(name: branch))
        .get(.make(job: ctx.parent))
      try ctx.storage.flow.change(accessory: branch, product: product, version: version)
    }
  }
}
