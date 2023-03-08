import Foundation
import Facility
import FacilityPure
public extension Ctx.Git {
  func getSha(sh: Ctx.Sh, ref: Ctx.Git.Ref) throws -> Ctx.Git.Sha { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: base + ["rev-parse", ref.value]
    )))
    .map(sh.execute)
    .map(Execute.parseText(reply:))
    .map(Ctx.Git.Sha.make(value:))
    .get()
  }
  func currentBranch(sh: Ctx.Sh) throws -> Ctx.Git.Branch? {
    let name = try Id
      .make(Execute.make(.make(
        environment: sh.env,
        arguments: base + ["branch", "--show-current"]
      )))
      .map(sh.execute)
      .map(Execute.parseText(reply:))
      .get()
    return try name.isEmpty.not
      .then(name)
      .map(Ctx.Git.Branch.make(name:))
  }
  func cat(sh: Ctx.Sh, file: Ctx.Git.File) throws -> Data { try Id
    .make(Execute.make(
      .make(
        environment: sh.env,
        arguments: base + ["show", "\(file.ref.value):\(file.path.value)"]
      ),
      lfs.then(.make(
        environment: sh.env, arguments: base + ["lfs", "smudge"]
      ))
    ))
    .map(sh.execute)
    .map(Execute.parseData(reply:))
    .get()
  }
  func isClean(sh: Ctx.Sh) throws -> Bool { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: base + ["status", "--porcelain"]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
    .isEmpty
  }
  func listAllTrackedFiles(sh: Ctx.Sh) throws -> [String] { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: base + unicode + ["ls-tree", "-r", "--name-only", "--full-tree", "HEAD", "."]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
  }
  func listCommits(
    sh: Ctx.Sh,
    in include: [Ctx.Git.Ref],
    notIn exclude: [Ctx.Git.Ref],
    noMerges: Bool = false,
    firstParents: Bool = false,
    boundary: Bool = false,
    ignoreMissing: Bool = false
  ) throws -> [Ctx.Git.Sha] {
    var arguments = base + ["log", "--format=%H"]
    if boundary { arguments.append("--boundary") }
    if firstParents { arguments.append("--first-parent") }
    if noMerges { arguments.append("--no-merges") }
    if ignoreMissing { arguments.append("--ignore-missing") }
    arguments += include.map(\.value)
    arguments += exclude.map({ "^\($0.value)" })
    return try Id
      .make(Execute.make(.make(environment: sh.env, arguments: arguments)))
      .map(sh.execute)
      .map(Execute.parseLines(reply:))
      .get()
      .map(Ctx.Git.Sha.make(value:))
  }
  func reset(
    sh: Ctx.Sh,
    ref: Ref,
    soft: Bool = false,
    hard: Bool = false
  ) throws {
    var arguments = base + ["reset"]
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
    var arguments = base + ["clean", "-fd"]
    if ignore { arguments.append("-x") }
    return try Id
      .make(Execute.make(.make(environment: sh.env, arguments: arguments)))
      .map(sh.execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  func listConflictMarkers(sh: Ctx.Sh) throws -> [String] { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: base + [
        "-c", "core.quotepath=false", "-c", "core.precomposeunicode=true",
        "-c", "core.whitespace=-trailing-space,-space-before-tab,-indent-with-non-tab,-tab-in-indent,-cr-at-eol",
        "diff", "--check", "HEAD"
      ]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
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
      .map(Self.make(root:))
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
private extension Ctx.Git {
  var base: [String] { ["git", "-C", root.value] }
  var unicode: [String] { ["-c", "core.quotepath=false", "-c", "core.precomposeunicode=true"] }
}
