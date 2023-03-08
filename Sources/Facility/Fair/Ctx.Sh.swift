import Foundation
import Facility
import FacilityPure
public extension Ctx.Sh {
  func get(env value: String) throws -> String {
    guard let result = env[value] else { throw Thrown("No env variable \(value)") }
    return result
  }
}
