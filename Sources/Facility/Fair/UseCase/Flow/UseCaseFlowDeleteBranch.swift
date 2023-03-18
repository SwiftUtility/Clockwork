import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowDeleteBranch: ProtectedContractPerformer {
    var name: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      _ = try ctx.getFlow()
      let defaultBranch = try Ctx.Git.Branch.make(name: ctx.project.defaultBranch)
      let branch: Ctx.Git.Branch
      if name.isEmpty.not {
        branch = try .make(name: name)
      } else {
        branch = try .make(job: ctx.parent)
        let sha = try Ctx.Git.Sha.make(job: ctx.parent)
        guard try ctx.gitCheck(child: branch.remote, parent: sha.ref)
        else { throw Thrown("Not last commit pipeline") }
      }
      guard branch != defaultBranch
      else { throw Thrown("Can not delete default branch \(defaultBranch.name)") }
      guard try ctx.gitCheck(child: defaultBranch.remote, parent: branch.remote)
      else { throw Thrown("Branch \(branch.name) not merged into \(defaultBranch.name)") }
      if let accessory = ctx.storage.flow.accessories[branch] {
        ctx.storage.flow.accessories[branch] = nil
        ctx.send(report: .accessoryBranchDeleted(
          parent: ctx.parent,
          accessory: accessory
        ))
      }
      if let release = ctx.storage.flow.releases[branch] {
        ctx.storage.flow.releases[branch] = nil
        ctx.send(report: .releaseBranchDeleted(
          parent: ctx.parent,
          release: release,
          kind: ctx.storage.flow.kind(release: release)
        ))
      }
      try ctx.deleteBranch(name: branch.name)
    }
  }
}
