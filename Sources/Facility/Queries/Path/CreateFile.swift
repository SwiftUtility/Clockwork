import Foundation
import Facility
public struct CreateFile: Query {
  public var file: String
  public var data: Data
  public init(file: String, data: Data) {
    self.file = file
    self.data = data
  }
  public typealias Reply = Void
}
