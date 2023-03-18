import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowCreateDeploy: ProtectedContractPerformer {
    var branch: String
    var commit: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
//      let branch: Ctx.Git.Branch = try branch.isEmpty.not
//        .then(.make(name: branch))
//        .get(.make(job: ctx.parent))
//      let sha: Ctx.Git.Sha = try commit.isEmpty.not
//        .then(.make(value: commit))
//        .get(.make(job: ctx.parent))
//      guard let release = ctx.storage.flow.releases[branch]
//      else { throw Thrown("No release branch \(branch.name)") }
//      let product = try ctx.storage.flow.product(name: release.product)
//      var family = try ctx.storage.flow.family(name: product.family)
//      let flow = try ctx.getFlow()
//      let deploy = try Flow.Deploy.make(
//        release: release,
//        build: family.nextBuild,
//        tag: generate(cfg.createTagName(
//          flow: flow,
//          product: release.product,
//          version: release.version,
//          build: family.nextBuild,
//          kind: .deploy
//        ))
//      )
//      guard ctx.storage.flow.deploys[deploy.tag] == nil
//      else { throw Thrown("Deploy already exists \(deploy.tag.name)") }
//      ctx.storage.flow.deploys[deploy.tag] = deploy
//      try family.bump(build: generate(cfg.bumpBuild(flow: flow, family: family)))
//      ctx.storage.flow.families[family.name] = family
//      let annotation = try generate(cfg.createTagAnnotation(
//        flow: flow,
//        product: deploy.product,
//        version: deploy.version,
//        build: deploy.build,
//        kind: .deploy
//      ))
//      guard try gitlab
//              .postTags(name: deploy.tag.name, ref: sha.value, message: annotation)
//              .map(execute)
//              .map(Execute.parseData(reply:))
//              .reduce(Json.GitlabTag.self, jsonDecoder.decode(_:from:))
//              .get()
//              .protected
//      else { throw Thrown("Tag not protected \(deploy.tag.name)") }
//      try Execute.checkStatus(reply: execute(cfg.git.fetchTag(deploy.tag)))
//      try cfg.reportDeployTagCreated(
//        commit: sha,
//        release: release,
//        deploy: deploy,
//        notes: makeNotes(cfg: cfg, storage: storage, release: release, deploy: deploy)
//      )
//
//      try perform(cfg: cfg, mutate: { storage in
//        return cfg.createFlowStorageCommitMessage(
//          flow: storage.flow,
//          reason: .createDeployTag,
//          product: deploy.product,
//          version: deploy.version.value,
//          build: deploy.build.value,
//          branch: release.branch.name,
//          tag: deploy.tag.name
//        )
//      })
//      return true
    }
  }
}
