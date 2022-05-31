import Foundation
import Facility
extension FileHandle {
  public func write(message: String) {
    write(.init("\(message)\n".utf8))
  }
}
