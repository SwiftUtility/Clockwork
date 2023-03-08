import Foundation
import Facility
import FacilityPure
public extension ContextLocal {
  func parse<T: Decodable>(type: T.Type, yaml: Ctx.Git.File) throws -> T {
    let yaml = try Id
    .make(yaml)
    .map(gitCat(file:))
    .map(String.make(utf8:))
    .map(sh.unyaml)
    .get()
    return try sh.dialect.read(type, from: yaml)
  }
  func parse(secret: Ctx.Secret) throws -> String {
    switch secret {
    case .value(let value): return value
    case .envVar(let envVar): return try get(env: envVar)
    case .envFile(let envFile): return try Id.make(envFile)
      .map(get(env:))
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
  func get(env: String) throws -> String { try sh.get(env: env) }
  func gitCat(file: Ctx.Git.File) throws -> Data { try sh.cat(git: repo.git, file: file) }
}
public extension Ctx.Sh {
  func gitTopLevel(path: Ctx.Sys.Absolute) throws -> Ctx.Sys.Absolute { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["git", "-C", path.value, "rev-parse", "--show-toplevel"],
      secrets: []
    )))
    .map(execute)
    .map(Execute.parseText(reply:))
    .map(Ctx.Sys.Absolute.make(value:))
    .get()
  }
  func updateLfs(git: inout Ctx.Git) throws { git.lfs = try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["git", "-C", git.root.value, "lfs", "update"],
      secrets: []
    )))
    .map(execute)
    .map(Execute.parseSuccess(reply:))
    .get()
  }
  func getSha(git: Ctx.Git, ref: Ctx.Git.Ref) throws -> Ctx.Git.Sha { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["git", "-C", git.root.value, "rev-parse", ref.value],
      secrets: []
    )))
    .map(execute)
    .map(Execute.parseText(reply:))
    .map(Ctx.Git.Sha.make(value:))
    .get()
  }
  func getCurrentBranch(git: Ctx.Git) throws -> Ctx.Git.Branch? {
    let name = try Id
      .make(Execute.make(.make(
        environment: env,
        arguments: ["git", "-C", git.root.value, "branch", "--show-current"],
        secrets: []
      )))
      .map(execute)
      .map(Execute.parseText(reply:))
      .get()
    return try name.isEmpty.not
      .then(name)
      .map(Ctx.Git.Branch.make(name:))
  }
  func cat(git: Ctx.Git, file: Ctx.Git.File) throws -> Data { try Id
    .make(Execute.make(
      .make(
        environment: env,
        arguments: ["git", "-C", git.root.value, "show", "\(file.ref.value):\(file.path.value)"]
      ),
      git.lfs.then(.make(
        environment: env, arguments: ["git", "-C", git.root.value, "lfs", "smudge"]
      ))
    ))
    .map(execute)
    .map(Execute.parseData(reply:))
    .get()
  }
  func get(env value: String) throws -> String {
    guard let result = env[value] else { throw Thrown("No env variable \(value)") }
    return result
  }
}
