import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowCreateStage: ProtectedContractPerformer {
    var product: String
    var build: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      let flow = try ctx.getFlow()
      let product = try ctx.storage.flow.product(name: product)
      let family = try ctx.storage.flow.family(name: product.family)
      guard let build = family.builds[build.alphaNumeric]
      else { throw Thrown("No build \(build) for \(product.name) reserved") }
      let version = ctx.storage.flow.releases[build.branch].map(\.version)
        .flatMapNil(ctx.storage.flow.accessories[build.branch]?.versions[product.name])
        .get(product.nextVersion)
      let stage = try Flow.Stage.make(
        tag: ctx.generateTagName(
          flow: flow,
          product: product.name,
          version: version,
          build: build.number,
          kind: .stage
        ),
        product: product,
        version: version,
        build: build.number,
        review: build.review,
        branch: build.branch
      )
      let annotation = try ctx.generateTagAnnotation(
        flow: flow,
        product: stage.product,
        version: stage.version,
        build: stage.build,
        kind: .stage
      )
      guard ctx.storage.flow.stages[stage.tag] == nil
      else { throw Thrown("Tag \(stage.tag.name) already exists") }
      ctx.storage.flow.stages[stage.tag] = stage
      guard try ctx
        .createTag(name: stage.tag.name, commit: build.commit, message: annotation)
        .protected
      else { throw Thrown("Stage not protected \(stage.tag.name)") }
      ctx.reportStageTagCreated(commit: build.commit, stage: stage)
    }
  }
}
