import Foundation
import Facility
import FacilityAutomates
public struct ListFileLines: Query {
  public var file: Path.Absolute
  public init(file: Path.Absolute) {
    self.file = file
  }
  public typealias Reply = AnyIterator<String>
}
