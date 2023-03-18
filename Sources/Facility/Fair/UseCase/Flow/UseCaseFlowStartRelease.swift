import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowStartRelease: ProtectedContractPerformer {
    var product: String
    var commit: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      let flow = try ctx.getFlow()
      let commit: Ctx.Git.Sha = try commit.isEmpty.not
        .then(.make(value: commit))
        .get(.make(job: ctx.parent))
      var product = try ctx.storage.flow.product(name: product)
      let release = try Flow.Release.make(
        product: product,
        version: product.nextVersion,
        commit: commit,
        branch: ctx.generateReleaseBranchName(
          flow: flow,
          product: product.name,
          version: product.nextVersion,
          kind: .release
        )
      )
      guard ctx.storage.flow.releases[release.branch] == nil
      else { throw Thrown("Release \(release.branch.name) already exists") }
      ctx.storage.flow.releases[release.branch] = release
      try product.bump(version: ctx.generateVersionBump(
        flow: flow,
        product: release.product,
        version: release.version,
        kind: .release
      ))
      ctx.storage.flow.products[product.name] = product
      guard try ctx.createBranches(name: release.branch.name, commit: commit).protected
      else { throw Thrown("Release \(release.branch.name) not protected") }
      try ctx.gitFetch(branch: release.branch)
      ctx.reportReleaseBranchCreated(
        release: release,
        kind: .release
      )
      try ctx.reportReleaseBranchSummary(release: release, notes: ctx.makeNotes(
        storage: ctx.storage.flow, release: release
      ))
    }
  }
}
