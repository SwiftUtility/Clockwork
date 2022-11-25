import Foundation
import Facility
public extension String {
  func get(env: [String: String]) throws -> String {
    try env[self].get { throw Thrown("No env \(self)") }
  }
  func getUInt() throws -> UInt {
    try UInt(self).get { throw Thrown("Not UInt: \(self)") }
  }
  func find(matches regexp: NSRegularExpression) throws -> [String] {
    var result: [String] = []
    for match in regexp.matches(
      in: self,
      options: .withoutAnchoringBounds,
      range: .init(startIndex..<endIndex, in: self)
    ) {
      guard match.range.location != NSNotFound, let range = Range(match.range, in: self)
      else { continue }
      result.append(String(self[range]))
    }
    return result
  }
}
