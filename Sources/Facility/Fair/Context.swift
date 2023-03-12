import Foundation
import Facility
import FacilityPure
extension Context {
  func get(env value: String) throws -> String {
    guard let result = sh.env[value] else { throw Thrown("No env variable \(value)") }
    return result
  }
  func sysDelete(path: String) throws { try Id
    .make(Execute.make(.make(environment: sh.env, arguments: ["rm", "-rf", path])))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func sysWrite(file: String, data: Data) throws { try Id
    .make(Execute.make(.make(environment: sh.env, arguments:  ["tee", file])))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func sysCreateDir(path: String) throws { try Id
    .make(Execute.make(.make(environment: sh.env, arguments: ["mkdir", "-p", path])))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func sysCreateTempFile() throws -> String { try Id
    .make(Execute.make(.make(environment: sh.env, arguments: ["mktemp"])))
    .map(sh.execute)
    .map(Execute.parseText(reply:))
    .get()
  }
  func makeGit(dir: Ctx.Sys.Absolute) throws -> Ctx.Git {
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
        arguments: ["git", "-C", result.root.value, "lfs", "update"],
        secrets: []
      )))
      .map(sh.execute)
      .map(Execute.parseSuccess(reply:))
      .get()
    return result
  }
}
