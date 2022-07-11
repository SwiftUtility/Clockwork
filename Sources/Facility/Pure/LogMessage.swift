import Foundation
import Facility
public struct LogMessage: Query {
  public var message: String
  public init(message: String) { self.message = message }
  public typealias Reply = Void
}
