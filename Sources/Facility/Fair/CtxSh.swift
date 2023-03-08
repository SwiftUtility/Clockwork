import Foundation
import Facility
import FacilityPure
public extension Ctx.Sh {
  func get(env value: String) throws -> String {
    guard let result = env[value] else { throw Thrown("No env variable \(value)") }
    return result
  }
  func delete(path: Ctx.Sys.Absolute) throws { try Id
    .make(Execute.make(.make(environment: env, arguments: ["rm", "-rf", path.value])))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func write(file: Files.Absolute, data: Data) throws { try Id
    .make(Execute.make(.make(environment: env, arguments:  ["tee", file.value])))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
}
