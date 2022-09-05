import Foundation
import Facility
import FacilityPure
public final class Reporter {
  let execute: Try.Reply<Execute>
  let writeStdout: Act.Of<String>.Go
  let readStdin: Try.Do<Execute.Reply>
  let generate: Try.Reply<Generate>
  let logMessage: Act.Reply<LogMessage>
  let worker: Worker
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    writeStdout: @escaping Act.Of<String>.Go,
    readStdin: @escaping Try.Do<Execute.Reply>,
    generate: @escaping Try.Reply<Generate>,
    logMessage: @escaping Act.Reply<LogMessage>,
    worker: Worker,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.writeStdout = writeStdout
    self.readStdin = readStdin
    self.generate = generate
    self.logMessage = logMessage
    self.worker = worker
    self.jsonDecoder = jsonDecoder
  }
  public func finish(cfg: Configuration, success: Bool) throws {
    if !success { throw Thrown("Execution considered unsuccessful") }
  }
  public func report(cfg: Configuration, error: Error) throws -> Bool {
    report(query: cfg.reportUnexpected(error: error))
    throw error
  }
  public func reportCustom(cfg: Configuration, event: String, stdin: Bool) throws -> Bool {
    let stdin = try stdin
      .then(readStdin())
      .map(Execute.parseLines(reply:))
      .get([])
    report(query: cfg.reportCustom(event: event, stdin: stdin))
    return true
  }
  public func reportReviewCustom(cfg: Configuration, event: String, stdin: Bool) throws -> Bool {
    let stdin = try stdin
      .then(readStdin())
      .map(Execute.parseLines(reply:))
      .get([])
    let ctx = try worker.resolveParentReview(cfg: cfg)
    try report(query: cfg.reportReviewCustom(
      event: event,
      review: ctx.review,
      users: worker.resolveParticipants(
        cfg: cfg,
        gitlabCi: ctx.gitlab,
        source: .make(sha: .init(value: ctx.job.pipeline.sha)),
        target: .make(remote: .init(name: ctx.review.targetBranch))
      ),
      stdin: stdin))
    return true
  }
  public func report(query: Report) -> Report.Reply {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    for value in query.cfg.communication.slackHookTextMessages[query.context.identity].get([]) {
      let message: String
      do {
        message = try generate(query.generate(template: value.createMessageText))
      } catch {
        logMessage(.init(message: "Generate report error: \(error)"))
        message = ""
      }
      guard !message.isEmpty else { continue }
      do { try Id(message)
        .map(value.makePayload(text:))
        .map(encoder.encode(_:))
        .map(String.make(utf8:))
        .reduce(value.url, query.cfg.curlSlackHook(url:payload:))
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
      } catch {
        logMessage(.init(message: "Delivery error: \(error)"))
        logMessage(.init(message: message))
      }
    }
  }
}
private extension Reporter {
  func merge(context: inout [String: AnyCodable], element: AnyCodable) throws {
    guard let element = element.map else { throw MayDay("wrong encodable structure") }
    try context.merge(element) { _,_ in throw MayDay("not unique unique") }
  }
}
