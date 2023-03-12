//import Foundation
//import Facility
//import FacilityPure
//public final class Logger {
//  let writeStderr: Act.Of<String>.Go
//  let getTime: Act.Do<Date>
//  let formatter: DateFormatter
//  public init(
//    writeStderr: @escaping Act.Of<String>.Go,
//    getTime: @escaping Act.Do<Date>
//  ) {
//    self.writeStderr = writeStderr
//    self.getTime = getTime
//    self.formatter = .init()
//    formatter.dateFormat = "HH:mm:ss"
//  }
//  public func logMessage(query: LogMessage) -> LogMessage.Reply { query.message
//    .split(separator: "\n")
//    .compactMap { line in line.isEmpty.else("[\(formatter.string(from: getTime()))]: \(line)") }
//    .forEach(writeStderr)
//  }
//}
