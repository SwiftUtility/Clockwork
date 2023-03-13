import Foundation
import Facility
import FacilityPure
public extension Ctx.Git {
  var base: [String] { ["git", "-C", root.value] }
  var unicode: [String] { ["-c", "core.quotepath=false", "-c", "core.precomposeunicode=true"] }
  func getSha(
    sh: Ctx.Sh,
    ref: Ctx.Git.Ref
  ) throws -> Ctx.Git.Sha { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["git", "-C", root.value, "rev-parse", ref.value]
    )))
    .map(sh.execute)
    .map(Execute.parseText(reply:))
    .map(Ctx.Git.Sha.make(value:))
    .get()
  }
  func getCurrentBranch(sh: Ctx.Sh) throws -> Ctx.Git.Branch? {
    let name = try Id
      .make(Execute.make(.make(
        environment: sh.env,
        arguments: ["git", "-C", root.value, "branch", "--show-current"]
      )))
      .map(sh.execute)
      .map(Execute.parseText(reply:))
      .get()
    return try name.isEmpty.not
      .then(name)
      .map(Ctx.Git.Branch.make(name:))
  }
  func getOriginUrl(sh: Ctx.Sh) throws -> String { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["git", "-C", root.value, "config", "--get", "remote.origin.url"]
    )))
    .map(sh.execute)
    .map(Execute.parseText(reply:))
    .get()
  }
  func reset(
    sh: Ctx.Sh,
    ref: Ctx.Git.Ref,
    soft: Bool = false,
    hard: Bool = false
  ) throws {
    var arguments = ["git", "-C", root.value, "reset"]
    if soft { arguments.append("--soft") }
    if hard { arguments.append("--hard") }
    arguments.append(ref.value)
    return try Id
      .make(Execute.make(.make(environment: sh.env, arguments: arguments)))
      .map(sh.execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  func clean(sh: Ctx.Sh, ignore: Bool = false) throws {
    var arguments = ["git", "-C", root.value, "clean", "-fd"]
    if ignore { arguments.append("-x") }
    return try Id
      .make(Execute.make(.make(environment: sh.env, arguments: arguments)))
      .map(sh.execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  static func make(sh: Ctx.Sh, dir: Ctx.Sys.Absolute) throws -> Self {
    var result = try Id
      .make(Execute.make(.make(
        environment: sh.env,
        arguments: ["git", "-C", dir.value, "rev-parse", "--show-toplevel"],
        secrets: []
      )))
      .map(sh.execute)
      .map(Execute.parseText(reply:))
      .map(Ctx.Sys.Absolute.make(value:))
      .map(Ctx.Git.make(root:))
      .get()
    result.lfs = try Id
      .make(Execute.make(.make(
        environment: sh.env,
        arguments: result.base + ["lfs", "update"],
        secrets: []
      )))
      .map(sh.execute)
      .map(Execute.parseSuccess(reply:))
      .get()
    return result
  }
}
