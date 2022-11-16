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
    report(query: cfg.reportUnexpected(error: error))
    throw error
  }
//  public func createThread(query: Report.CreateThread) throws -> Report.CreateThread.Reply {
//    logMessage(.init(message: "Creating thread for: \(query.report.context.identity)"))
//    report(query: query.report)
//    let slack = try query.report.cfg.slack.get()
//    var query = query
//    query.report.context.env = query.report.cfg.env
//    query.report.context.info = try? query.report.cfg.gitlabCi.get().info
//    query.report.context.mark = "createThread"
//    let body = try generate(query.report.generate(template: query.template))
//    return try Id
//    .make(query.report.cfg.curlSlack(
//      token: slack.token,
//      method: "chat.postMessage",
//      body: body
//    ))
//    .map(execute)
//    .map(Execute.parseData(reply:))
//    .reduce(Json.SlackMessage.self, jsonDecoder.decode(_:from:))
//    .map(Configuration.Thread.make(slack:))
//    .get()
//  }
  public func readStdin(query: Configuration.ReadStdin) throws -> Configuration.ReadStdin.Reply {
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
  public func reportCustom(
    cfg: Configuration,
    event: String,
    stdin: Configuration.ReadStdin
  ) throws -> Bool {
    let stdin = try readStdin(query: stdin)
    report(query: cfg.reportCustom(event: event, stdin: stdin))
    return true
  }
  public func report(query: Report) -> Report.Reply {
//    logMessage(.init(message: "Creating report for: \(query.info.event)"))
//    var query = query
//    query.info.env = query.cfg.env
//    query.info.gitlab = try? query.cfg.gitlabCi.get().ctx
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
    let slack: Slack
    switch report.cfg.slack {
    case .none: return
    case .some(.error(let error)):
      logMessage(.init(message: "Report \(report.info.event.joined(separator: "/")) failed: \(error)"))
      return
    case .some(.value(let value)): slack = value
    }
    var report = report
    let signals = slack.signals.filter(report.info.triggers(signal:))
    guard signals.isEmpty.not else { return }
    logMessage(.init(message: "Reporting slack \(report.info.event.joined(separator: "/"))"))
    for signal in slack.signals.filter(report.info.triggers(signal:)) {
      report.info.mark = signal.mark
      do { _ = try send(report: report, slack: slack, signal: signal) }
      catch { logMessage(.init(message: "\(error)")) }
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
