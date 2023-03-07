import Foundation
import Facility
public extension ContextLocal {
  func parse<T: Decodable>(type: T.Type, yaml: Ctx.Git.File) throws -> T {
    let yaml = try Id
    .make(yaml)
    .reduce(repo.git, sh.cat(git:file:))
    .map(String.make(utf8:))
    .map(sh.unyaml)
    .get()
    return try sh.dialect.read(type, from: yaml)
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
      .reduce(repo.git, sh.cat(git:file:))
      .map(String.make(utf8:))
      .get()
    }
  }
}
