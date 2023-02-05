import Foundation
import Facility
import FacilityPure
public final class Reporter {
  let execute: Try.Reply<Execute>
  let writeStdout: Act.Of<String>.Go
  let readStdin: Try.Do<Data?>
  let generate: Try.Reply<Generate>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    writeStdout: @escaping Act.Of<String>.Go,
    readStdin: @escaping Try.Do<Data?>,
    generate: @escaping Try.Reply<Generate>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.writeStdout = writeStdout
    self.readStdin = readStdin
    self.generate = generate
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func finish(cfg: Configuration, success: Bool) throws {
    if !success { throw Thrown("Execution considered unsuccessful") }
  }
  public func report(cfg: Configuration, error: Error) throws -> Bool {
    report(query:  cfg.reportUnexpected(error: error))
    throw error
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
  public func report(query: Report) -> Report.Reply {
    logMessage(.init(message: "Reporting \(query.info.event)"))
    var query = query
//    query.info.env = query.cfg.env
//    query.info.jira = try? query.cfg.jira.get().context
//    query.info.slack = try? query.cfg.slack
//      .map(query.cfg.parseSlackStorage(slack:))
//      .map(parseSlackStorage)
//      .map(Slack.Context.make(storage:))
//      .get()
//    query.info.gitlab = try? query.cfg.gitlab.get().info


//    var env: [String: String] { get set }
//    var gitlab: Gitlab.Context? { get set }
//    var mark: String? { get set }
//    var jira: Jira.Context? { get set }
//    var slack: Slack.Context? { get set }

    //    do { slack = try query.cfg.slack.get() }
//    catch { return logMessage(.init(message: "Report failed: \(error)")) }
//    for (event, signal) in slack.signals {
//      query.info.mark = signal.mark
//      let body: String
//      do {
//        body = try generate(query.generate(template: signal.body))
//        guard !body.isEmpty else {
//          logMessage(.init(message: "Report is empty"))
//          continue
//        }
//      } catch {
//        logMessage(.init(message: "Generate report error: \(error)"))
//        continue
//      }
//      do {
//        try Execute.checkStatus(reply: execute(query.cfg.curlSlack(
//          token: slack.token,
//          method: signal.method,
//          body: body
//        )))
//        sleep(1)
//      } catch {
//        logMessage(.init(message: "Report delivery failed: \(error)"))
//        logMessage(.init(message: body))
//      }
//    }
  }
  func slack(report: Report) {
    guard report.cfg.profile.slack != nil else { return }
    let slack: Slack
    do { slack = try report.cfg.slack.get() }
    catch { return logMessage(.init(message: "Report slack failed: \(error)")) }
    let signals = slack.signals.filter(report.info.triggers(signal:))
    guard signals.isEmpty.not else { return }
    logMessage(.init(message: "Reporting slack \(report.info.event.joined(separator: "/"))"))
    for signal in slack.signals.filter(report.info.triggers(signal:)) {
      var report = report
      report.info.mark = signal.mark
      do { _ = try send(report: report, slack: slack, signal: signal) }
      catch { logMessage(.init(message: "\(error)")) }
    }
    if let gitlab = slack.gitlab {
      for thread in gitlab.branches {

      }
    }
  }
  func send(report: Report, slack: Slack, signal: Slack.Signal) throws -> Json.SlackMessage? {
    let body = try generate(report.generate(template: signal.body))
    guard !body.isEmpty else { throw Thrown("Skip report \(signal.mark): empty body") }
    logMessage(.init(message: "Reporting \(signal.mark): \(body)"))
    let data = try Execute.parseData(reply: execute(report.cfg.curlSlack(
      token: slack.token,
      method: signal.method,
      body: body
    )))
    sleep(1)
    return try jsonDecoder.decode(Json.SlackMessage.self, from: data)
  }
}
