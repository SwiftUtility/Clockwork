import Foundation
import Facility
import FacilityPure
public extension Context {
  func log(message: String) {
    sh.stderr(.init("[\(sh.formatter.string(from: sh.getTime()))]: \(message)\n".utf8))
  }
  func parse(secret: Ctx.Secret) throws -> String {
    switch secret {
    case .value(let value): return value
    case .envVar(let envVar): return try sh.get(env: envVar)
    case .envFile(let envFile): return try Id.make(envFile)
      .map(sh.get(env:))
      .map(Ctx.Sys.Absolute.make(value:))
      .map(sh.read)
      .map(String.make(utf8:))
      .get()
    case .sysFile(let sysFile): return try Id(sysFile)
      .map(Ctx.Sys.Absolute.Resolve.make(path:))
      .map(sh.resolveAbsolute)
      .map(sh.read)
      .map(String.make(utf8:))
      .get()
    case .gitFile(let gitFile): return try Id(gitFile)
      .map(gitCat(file:))
      .map(String.make(utf8:))
      .get()
    }
  }
  func gitGetSha(ref: Ctx.Git.Ref) throws -> Ctx.Git.Sha {
    try git.getSha(sh: sh, ref: ref)
  }
  func gitCat(file: Ctx.Git.File) throws -> Data { try Id
    .make(Execute.make(
      .make(
        environment: sh.env,
        arguments: git.base + ["show", "\(file.ref.value):\(file.path.value)"]
      ),
      git.lfs.then(.make(
        environment: sh.env,
        arguments: git.base + ["lfs", "smudge"]
      ))
    ))
    .map(sh.execute)
    .map(Execute.parseData(reply:))
    .get()
  }
  func gitIsClean() throws -> Bool { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: git.base + ["status", "--porcelain"]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
    .isEmpty
  }
  func gitListAllTrackedFiles() throws -> [String] { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: git.base + git.unicode
      + ["ls-tree", "-r", "--name-only", "--full-tree", "HEAD", "."]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
  }
  func gitListTreeTrackedFiles(dir: Ctx.Git.Dir) throws -> [Ctx.Sys.Relative] { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: git.base + git.unicode
      + ["ls-tree", "-r", "--name-only", "--full-tree", dir.ref.value, dir.path.value]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
    .map(Ctx.Sys.Relative.make(value:))
  }
  func gitListCommits(
    in include: [Ctx.Git.Ref],
    notIn exclude: [Ctx.Git.Ref],
    noMerges: Bool = false,
    firstParents: Bool = false,
    boundary: Bool = false,
    ignoreMissing: Bool = false
  ) throws -> [Ctx.Git.Sha] {
    var arguments = git.base + ["log", "--format=%H"]
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
  func gitReset(
    ref: Ctx.Git.Ref,
    soft: Bool = false,
    hard: Bool = false
  ) throws {
    try git.reset(sh: sh, ref: ref, soft: soft, hard: hard)
  }
  func gitClean(ignore: Bool = false) throws {
    try git.clean(sh: sh, ignore: ignore)
  }
  func gitMergeBase(_ one: Ctx.Git.Ref, _ two: Ctx.Git.Ref) throws -> Ctx.Git.Sha { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: git.base + ["merge-base", one.value, two.value]
    )))
    .map(sh.execute)
    .map(Execute.parseText(reply:))
    .map(Ctx.Git.Sha.make(value:))
    .get()
  }
  func gitCheck(child: Ctx.Git.Ref, parent: Ctx.Git.Ref) throws -> Bool { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: git.base + ["merge-base", "--is-ancestor", parent.value, child.value]
    )))
    .map(sh.execute)
    .map(Execute.parseSuccess(reply:))
    .get()
  }
  func gitListParents(ref: Ctx.Git.Ref) throws -> [Ctx.Git.Sha] { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: git.base + ["rev-parse", "\(ref.value)^@"]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
    .map(Ctx.Git.Sha.make(value:))
  }
  func gitListConflictMarkers() throws -> [String] { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: git.base + [
        "-c", "core.quotepath=false", "-c", "core.precomposeunicode=true",
        "-c", "core.whitespace=-trailing-space,-space-before-tab,-indent-with-non-tab,-tab-in-indent,-cr-at-eol",
        "diff", "--check", "HEAD"
      ]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
  }
}
