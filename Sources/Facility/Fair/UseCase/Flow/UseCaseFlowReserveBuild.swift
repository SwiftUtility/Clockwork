import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowReserveBuild: ContractPerformer {
    var product: String
    func perform(gitlab ctx: ContextGitlab) throws -> Bool {
      guard let flow = try ctx.parseFlow()
      else { throw Thrown("No flow in profile") }
      let storage = try ctx.parseStorage(flow: flow)
      let product = try storage.product(name: product)
      let family = try storage.family(name: product.family)
      let sha = try Ctx.Git.Sha.make(job: ctx.gitlab.current)
      if ctx.gitlab.current.isReview {
        let review = try ctx.gitlab.current.review.get()
        guard family.build(review: review, commit: sha) == nil else { return true }
      } else {
        let branch = try Ctx.Git.Branch.make(job: ctx.gitlab.current)
        guard family.build(commit: sha, branch: branch) == nil else { return true }
      }
      _ = try defaultPerform(gitlab: ctx)
      return false
    }
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      let flow = try ctx.getFlow()
      let product = try ctx.storage.flow.product(name: product)
      var family = try ctx.storage.flow.family(name: product.family)
      let sha = try Ctx.Git.Sha.make(job: ctx.parent)
      var build: Flow.Build? = nil
      if ctx.parent.isReview {
        let review = try ctx.parent.review.get()
        if family.build(review: review, commit: sha) == nil {
          let branch = try Ctx.Git.Branch.make(name: ctx.getMerge(iid: review).targetBranch)
          build = .make(number: family.nextBuild, review: review, commit: sha, branch: branch)
        }
      } else {
        let branch = try Ctx.Git.Branch.make(job: ctx.parent)
        let sha = try Ctx.Git.Sha.make(job: ctx.parent)
        if family.build(commit: sha, branch: branch) == nil {
          build = .make(number: family.nextBuild, review: nil, commit: sha, branch: branch)
        }
      }
      if let build = build {
        family.builds[build.number] = build
        try family.bump(build: ctx.generateBuildBump(flow: flow, family: family))
        ctx.storage.flow.families[family.name] = family
      }
      try ctx.retry(job: ctx.parent)
    }
  }
}
