import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowDeleteTag: ProtectedContractPerformer {
    var name: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      _ = try ctx.getFlow()
      let tag: Ctx.Git.Tag = try name.isEmpty.not
        .then(.make(name: name))
        .get(.make(job: ctx.parent))
      if let stage = ctx.storage.flow.stages[tag] {
        ctx.storage.flow.stages[tag] = nil
        ctx.send(report: .stageTagDeleted(parent: ctx.parent, stage: stage))
      }
      if let deploy = ctx.storage.flow.deploys[tag] {
        ctx.storage.flow.deploys[tag] = nil
        ctx.send(report: .deployTagDeleted(
          parent: ctx.parent,
          deploy: deploy,
          release: ctx.storage.flow.release(deploy: deploy)
        ))
      }
      try ctx.deleteTag(name: tag.name)
    }
  }
}
