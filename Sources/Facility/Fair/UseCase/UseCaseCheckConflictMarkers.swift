import Foundation
import Facility
import FacilityPure
public extension UseCase {
  struct CheckConflictMarkers: Performer {
    public var target: String
    public var stdout: Bool
    public static func make(target: String, stdout: Bool) -> Self {
      .init(target: target, stdout: stdout)
    }
    public func perform(repo ctx: ContextRepo) throws -> Bool {
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
