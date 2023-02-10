import Foundation
import Facility
import FacilityPure
public final class Reporter {
  let execute: Try.Reply<Execute>
  let writeStdout: Act.Of<String>.Go
  let sendSlack: Act.Reply<Slack.Send>
  let readStdin: Try.Do<Data?>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    writeStdout: @escaping Act.Of<String>.Go,
    sendSlack: @escaping Act.Reply<Slack.Send>,
    readStdin: @escaping Try.Do<Data?>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.writeStdout = writeStdout
    self.sendSlack = sendSlack
    self.readStdin = readStdin
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func parseStdin(query: Configuration.ParseStdin) throws -> Configuration.ParseStdin.Reply {
    switch query {
    case .ignore: return nil
    case .lines:
      let stdin = try readStdin()
        .map(String.make(utf8:))?
        .trimmingCharacters(in: .newlines)
        .components(separatedBy: .newlines)
      return try stdin.map(AnyCodable.init(any:))
    case .json: return try readStdin().reduce(AnyCodable.self, jsonDecoder.decode(_:from:))
    }
  }
  public func sendReports(cfg: Configuration) {
    var reports = Report.Bag.shared.reports
    guard
      let gitlab = try? cfg.gitlab.get(),
      let project = try? gitlab.project.get()
    else { return }
    let active = gitlab.storage.users
      .filter(\.value.active)
      .keySet
      .subtracting(gitlab.storage.bots)
    let info = gitlab.info
    let jira = try? cfg.jira.get().info
    for index in reports.indices {
      reports[index].threads.users.formIntersection(active)
      reports[index].threads.branches.remove(project.defaultBranch)
      reports[index].info.env = cfg.env
      reports[index].info.gitlab = info
      if let merge = reports[index].merge { reports[index].info.gitlab?.merge = merge }
      reports[index].info.jira = jira
    }
    sendSlack(.make(cfg: cfg, reports: reports))
  }
}
