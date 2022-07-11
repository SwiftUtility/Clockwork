import Foundation
import Facility
import FacilityPure
extension FileHandle {
  public func write(message: String) {
    write(.init("\(message)\n".utf8))
  }
  public static func readStdin() throws -> Execute.Reply {
    try .init(data: standardInput.readToEnd(), statuses: [])
  }
}
