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
  public func createThread(query: Report.CreateThread) throws -> Report.CreateThread.Reply {
    logMessage(.init(message: "Creating thread for: \(query.report.context.identity)"))
    report(query: query.report)
    let slack = try query.report.cfg.slack.get()
    var query = query
    query.report.context.env = query.report.cfg.env
    query.report.context.info = try? query.report.cfg.gitlabCi.get().info
    query.report.context.mark = "createThread"
    let body = try generate(query.report.generate(template: query.template))
    return try Id
    .make(query.report.cfg.curlSlack(
      token: slack.token,
      method: "chat.postMessage",
      body: body
    ))
    .map(execute)
    .map(Execute.parseData(reply:))
    .reduce(Json.SlackMessage.self, jsonDecoder.decode(_:from:))
    .map(Configuration.Thread.make(slack:))
    .get()
  }
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
    logMessage(.init(message: "Creating report for: \(query.context.identity)"))
    var query = query
    query.context.env = query.cfg.env
    query.context.info = try? query.cfg.gitlabCi.get().info
    let slack: Slack
    do { slack = try query.cfg.slack.get() }
    catch { return logMessage(.init(message: "Report failed: \(error)")) }
    for signal in slack.signals[query.context.identity].get([]) {
      query.context.mark = signal.mark
      let body: String
      do {
        body = try generate(query.generate(template: signal.body)).debug()
        guard !body.isEmpty else { continue }
      } catch {
        logMessage(.init(message: "Generate report error: \(error)"))
        continue
      }
      do { try Execute.checkStatus(reply: execute(query.cfg.curlSlack(
        token: slack.token,
        method: signal.method,
        body: body
      ))) } catch {
        logMessage(.init(message: "Report delivery failed: \(error)"))
        logMessage(.init(message: body))
      }
    }
  }
}
