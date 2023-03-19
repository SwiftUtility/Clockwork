import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowCreateDeploy: ProtectedContractPerformer {
    var branch: String
    var commit: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      let flow = try ctx.getFlow()
      if commit.isEmpty {
        branch = ctx.parent.pipeline.ref
        commit = ctx.parent.pipeline.sha
      }
      let branch = try Ctx.Git.Branch.make(name: branch)
      let commit = try Ctx.Git.Sha.make(value: commit)
      guard let release = ctx.storage.flow.releases[branch]
      else { throw Thrown("No release branch \(branch.name)") }
      let product = try ctx.storage.flow.product(name: release.product)
      var family = try ctx.storage.flow.family(name: product.family)
      let deploy = try Flow.Deploy.make(
        release: release,
        build: family.nextBuild,
        tag: ctx.generateTagName(
          flow: flow,
          product: release.product,
          version: release.version,
          build: family.nextBuild,
          kind: .deploy
        )
      )
      guard ctx.storage.flow.deploys[deploy.tag] == nil
      else { throw Thrown("Deploy already exists \(deploy.tag.name)") }
      ctx.storage.flow.deploys[deploy.tag] = deploy
      try family.bump(build: ctx.generateBuildBump(flow: flow, family: family))
      ctx.storage.flow.families[family.name] = family
      let annotation = try ctx.generateTagAnnotation(
        flow: flow,
        product: deploy.product,
        version: deploy.version,
        build: deploy.build,
        kind: .deploy
      )
      let notes = try ctx.makeNotes(
        storage: ctx.storage.flow,
        release: release,
        commit: commit,
        deploy: deploy
      )
      guard try ctx.createTag(name: deploy.tag.name, commit: commit, message: annotation).protected
      else { throw Thrown("Tag not protected \(deploy.tag.name)") }
      ctx.reportDeployTagCreated(
        commit: commit,
        release: release,
        deploy: deploy,
        notes: notes
      )
    }
  }
}
