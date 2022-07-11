import Foundation
import Facility
import FacilityPure
public class FileLiner {
  private let file: UnsafeMutablePointer<FILE>
  private var buffer: UnsafeMutablePointer<CChar>? = nil
  private var size = 0
  private init(file: Files.Absolute) throws {
    self.file = try fopen(file.value, "r").get { throw Thrown("Unable to open \(file)") }
  }
  private func readLine() -> String? {
    guard getline(&buffer, &size, file) > 0 else { return nil }
    return try? String(cString: ?!buffer).trimmingCharacters(in: .newlines)
  }
  deinit {
    fclose(file)
    guard let buffer = buffer else { return }
    buffer.deinitialize(count: size)
    buffer.deallocate()
  }
  public static func listFileLines(query: Files.ListFileLines) throws -> Files.ListFileLines.Reply {
    try .init(FileLiner(file: query.file).readLine)
  }
}
