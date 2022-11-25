import Foundation
import Facility
import FacilityPure
public final class Slacker {
  let parseSlackStorage: Try.Reply<ParseYamlFile<Slack.Storage>>
  public init(
    parseSlackStorage: @escaping Try.Reply<ParseYamlFile<Slack.Storage>>
  ) {
    self.parseSlackStorage = parseSlackStorage
  }
//  public func loadContext(query: Slack.Context.Load) -> LogMessage.Reply { query.message
//    .split(separator: "\n")
//    .compactMap { line in line.isEmpty.else("[\(formatter.string(from: getTime()))]: \(line)") }
//    .forEach(writeStderr)
//  }
}
