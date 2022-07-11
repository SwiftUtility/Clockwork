import Foundation
import Facility
public extension String {
  func get(env: [String: String]) throws -> String {
    try env[self].get { throw Thrown("No env \(self)") }
  }
  func getUInt() throws -> UInt {
    try UInt(self).get { throw Thrown("Not UInt: \(self)") }
  }
}
