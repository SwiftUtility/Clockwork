import Foundation
import Facility
import FacilityPure
public extension Ctx.Sh {
  func get(env value: String) throws -> String {
    guard let result = env[value] else { throw Thrown("No env variable \(value)") }
    return result
  }
  func delete(path: String) throws { try Id
    .make(Execute.make(.make(environment: env, arguments: ["rm", "-rf", path])))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func write(file: String, data: Data) throws { try Id
    .make(Execute.make(.make(environment: env, arguments:  ["tee", file])))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func createDir(path: String) throws { try Id
    .make(Execute.make(.make(environment: env, arguments: ["mkdir", "-p", path])))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func createTempFile() throws -> String { try Id
    .make(Execute.make(.make(environment: env, arguments: ["mktemp"])))
    .map(execute)
    .map(Execute.parseText(reply:))
    .get()
  }
}
