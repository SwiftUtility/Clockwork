import Foundation
import Facility
import FacilityPure
extension FileHandle {
  public func write(message: String) {
    write(.init("\(message)\n".utf8))
  }
  public func write(data: Data) {
    write(data)
  }
  public static func readStdin() throws -> Data? {
    try standardInput.readToEnd()
  }
}
