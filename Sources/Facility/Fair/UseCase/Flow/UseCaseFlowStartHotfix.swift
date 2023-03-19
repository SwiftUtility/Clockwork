import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowStartHotfix: ProtectedContractPerformer {
    var product: String
    var commit: String
    var version: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      let flow = try ctx.getFlow()
      if commit.isEmpty {
        let tag = try Ctx.Git.Tag.make(job: ctx.parent)
        commit = try ctx.gitGetSha(ref: tag.ref).value
        guard let deploy = ctx.storage.flow.deploys[tag]
        else { throw Thrown("No deploy for \(tag.name)") }
        version = deploy.version.value
        product = deploy.product
      }
      let product = try ctx.storage.flow.product(name: product)
      let version = try ctx.generateVersionBump(
        flow: flow,
        product: product.name,
        version: version.alphaNumeric,
        kind: .hotfix
      ).alphaNumeric
      let release = try Flow.Release.make(
        product: product,
        version: version,
        commit: .make(value: commit),
        branch: ctx.generateReleaseBranchName(
          flow: flow,
          product: product.name,
          version: version,
          kind: .hotfix
        )
      )
      guard let min = product.prevVersions.min()
      else { throw Thrown("No previous releases of \(product.name)") }
      guard min < version
      else { throw Thrown("Version \(version.value) must be greater than \(min.value)") }
      guard product.nextVersion > version else { throw Thrown(
        "Version \(version.value) must be less than \(product.nextVersion.value)"
      )}
      guard ctx.storage.flow.releases[release.branch] == nil
      else { throw Thrown("Release \(release.branch.name) already exists") }
      ctx.storage.flow.releases[release.branch] = release
      let notes = try ctx.makeNotes(storage: ctx.storage.flow, release: release)
      guard try ctx.createBranch(name: release.branch.name, commit: release.start).protected
      else { throw Thrown("Release \(release.branch.name) not protected") }
      ctx.reportReleaseBranchCreated(release: release, kind: .hotfix)
      ctx.reportReleaseBranchSummary(release: release, notes: notes)
    }
  }
}
