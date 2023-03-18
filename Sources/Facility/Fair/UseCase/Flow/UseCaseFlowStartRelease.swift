import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowStartRelease: ProtectedContractPerformer {
    var product: String
    var commit: String
    mutating func perform(exclusive ctx: ContextExclusive) throws {
      let flow = try ctx.getFlow()
      #warning("TBD")
//      let gitlab = try cfg.gitlab.get()
//      let commit = try commit.isEmpty.not
//        .then(Git.Sha.make(value: commit))
//        .get(.make(job: gitlab.job))
//      try perform(cfg: cfg, mutate: { storage in
//        var product = try storage.product(name: product)
//        let release = try Flow.Release.make(
//          product: product,
//          version: product.nextVersion,
//          commit: commit,
//          branch: generate(cfg.createReleaseBranchName(
//            flow: storage.flow,
//            product: product.name,
//            version: product.nextVersion,
//            kind: .release
//          ))
//        )
//        guard storage.releases[release.branch] == nil
//        else { throw Thrown("Release \(release.branch.name) already exists") }
//        storage.releases[release.branch] = release
//        try product.bump(version: generate(cfg.bumpVersion(
//          flow: storage.flow,
//          product: release.product,
//          version: release.version,
//          kind: .release
//        )))
//        storage.products[product.name] = product
//        guard try gitlab
//                .postBranches(name: release.branch.name, ref: commit.value)
//                .map(execute)
//                .map(Execute.parseData(reply:))
//                .reduce(Json.GitlabBranch.self, jsonDecoder.decode(_:from:))
//                .get()
//                .protected
//        else { throw Thrown("Release \(release.branch.name) not protected") }
//        try Execute.checkStatus(reply: execute(cfg.git.fetchBranch(release.branch)))
//        cfg.reportReleaseBranchCreated(
//          release: release,
//          kind: .release
//        )
//        try cfg.reportReleaseBranchSummary(release: release, notes: makeNotes(
//          cfg: cfg, storage: storage, release: release
//        ))
//        return cfg.createFlowStorageCommitMessage(
//          flow: storage.flow,
//          reason: .createReleaseBranch,
//          product: release.product,
//          version: release.version.value,
//          branch: release.branch.name
//        )
//      })
//      return true
    }
  }
}
