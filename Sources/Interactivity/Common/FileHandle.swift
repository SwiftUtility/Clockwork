import Foundation
import Facility
import FacilityPure
extension FileHandle {
  public func write(message: String) {
    write(.init("\(message)\n".utf8))
  }
  public static func read(file: Ctx.Sys.Absolute) throws -> Data {
    try .init(contentsOf: .init(fileURLWithPath: file.value))
  }
  public static func lineIterator(file: Ctx.Sys.Absolute) throws -> AnyIterator<String> {
    try .init(FileLiner(file: file).readLine)
  }
  class FileLiner {
    private let file: UnsafeMutablePointer<FILE>
    private var buffer: UnsafeMutablePointer<CChar>? = nil
    private var size = 0
    init(file: Ctx.Sys.Absolute) throws {
      self.file = try fopen(file.value, "r").get { throw Thrown("Unable to open \(file)") }
    }
    func readLine() -> String? {
      guard getline(&buffer, &size, file) > 0 else { return nil }
      return try? String(cString: ?!buffer).trimmingCharacters(in: .newlines)
    }
    deinit {
      fclose(file)
      guard let buffer = buffer else { return }
      buffer.deinitialize(count: size)
      buffer.deallocate()
    }
  }
}
