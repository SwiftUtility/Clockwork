import Foundation
import Facility
import FacilityAutomates
public struct ReadFile: Query {
  public var file: Path.Absolute
  public init(file: Path.Absolute) throws {
    self.file = file
  }
  public typealias Reply = Data
}
