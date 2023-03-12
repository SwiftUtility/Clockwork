import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct FusionExport: ProtectedGitlabPerformer {
    var fork: String
    var source: String
    func perform(gitlab ctx: ContextGitlab, protected: Ctx.Gitlab.Protected) throws -> Bool {
      let fork = try Ctx.Git.Sha.make(value: fork)
      let source = try Ctx.Git.Branch.make(name: source)
      var targets = try ctx.listBranches(protected: protected)
        .filter(\.protected)
        .map(\.name)
        .map(Ctx.Git.Branch.make(name:))
        .filter({ (try? ctx.gitMergeBase($0.remote, fork.ref)) != nil })
        .reduce(into: Set(), { $0.insert($1) })
      targets.remove(source)
      guard targets.isEmpty.not else { return false }
      let integrate = targets.sorted()
      let propogate = try integrate
        .filter({ try ctx.gitCheck(child: $0.remote, parent: fork.ref) })
      let duplicate = try ctx.gitListParents(ref: fork.ref).count == 1
      try ctx.sh.stdout(ctx.sh.rawEncoder.encode(Json.FusionTargets.make(
        fork: fork,
        source: source,
        integrate: integrate,
        duplicate: duplicate,
        propogate: propogate
      )))
      return true
    }
  }
}
