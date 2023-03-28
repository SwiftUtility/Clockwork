import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FlowExportVersions: Performer {
    var product: String
    func perform(local ctx: ContextLocal) throws -> Bool {
      guard let flow = try ctx.parseFlow()
      else { throw Thrown("No flow in profile") }
      let storage = try ctx.parseStorage(flow: flow)
      var versions = storage.products.mapValues(\.nextVersion.value)
      var branch: String? = try? ctx.sh.get(env: "CI_MERGE_REQUEST_TARGET_BRANCH_NAME")
      if branch == nil { branch = try? ctx.sh.get(env: "CI_COMMIT_BRANCH") }
      if let branch = branch {
        let branch = Ctx.Git.Branch.make(name: branch)
        if let release = try storage.releases[branch] {
          versions[release.product] = release.version.value
        } else if let accessory = try storage.accessories[branch] {
          for (product, version) in accessory.versions {
            versions[product] = version.value
          }
        }
      }


      if let target = ctx.sh.get(env: "CI_MERGE_REQUEST_TARGET_BRANCH_NAME")
      "CI_COMMIT_BRANCH"
      "CI_COMMIT_TAG"
      "CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
      if let target = ctx.sh.get(env: "CI_COMMIT_BRANCH")
      var build: String? = nil
      if product.isEmpty {
        if let gitlab = try? ctx.gitlab()

      } else {

      }
      #warning("TBD")
      return true
    }
  }
}
