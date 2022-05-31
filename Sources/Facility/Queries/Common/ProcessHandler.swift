import Foundation
import Facility
import FacilityAutomates
public protocol ProcessHandler: Query {
  var tasks: [PipeTask] { get }
  func handle(data: Data) throws -> Reply
}
