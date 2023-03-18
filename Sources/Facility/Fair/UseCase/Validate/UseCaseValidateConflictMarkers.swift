import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ValidateConflictMarkers: Performer {
    var target: String
    var stdout: Bool
    func perform(local ctx: ContextLocal) throws -> Bool {
      guard try ctx.gitIsClean() else { throw Thrown("Git is dirty") }
      guard let fork = try ctx.gitListCommits(
        in: [.head],
        notIn: [.make(remote: target)],
        boundary: true
      ).last else { throw Thrown("Fork point not found") }
      let initial = try ctx.gitGetSha(ref: .head).ref
      try ctx.gitReset(ref: fork.ref, soft: true)
      let result = try ctx.gitListConflictMarkers()
      try ctx.gitReset(ref: initial, hard: true)
      try ctx.gitClean()
      result.forEach(ctx.log(message:))
      if stdout { try ctx.sh.stdout(ctx.sh.rawEncoder.encode(result)) }
      return result.isEmpty
    }
  }
}
