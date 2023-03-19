import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowCreateAccessory: ProtectedContractPerformer {
    var name: String
    var commit: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      let flow = try ctx.getFlow()
      let commit: Ctx.Git.Sha = try commit.isEmpty.not
        .then(.make(value: commit))
        .get(.make(job: ctx.parent))
      let accessory = try Flow.Accessory.make(branch: name)
      guard ctx.storage.flow.accessories[accessory.branch] == nil
      else { throw Thrown("Branch \(accessory.branch.name) already present") }
      ctx.storage.flow.accessories[accessory.branch] = accessory
      guard try ctx.createBranch(name: accessory.branch.name, commit: commit).protected
      else { throw Thrown("\(accessory.branch.name) not protected") }
      ctx.reportAccessoryBranchCreated(commit: commit, accessory: accessory)
    }
  }
}
