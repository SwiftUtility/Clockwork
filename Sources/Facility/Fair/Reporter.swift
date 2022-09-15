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
  public func createThread(query: Report.CreateThread) throws -> Report.CreateThread.Reply {
    let token = try query.report.cfg.slackToken.get()
    let body = try generate(query.report.generate(template: query.template))
    let data = try Execute.parseData(reply: execute(query.report.cfg.curlSlack(
      token: token,
      method: "chat.postMessage",
      body: body
    )))
    self.report(query: query.report)
    return try jsonDecoder.decode(Yaml.Thread.self, from: data)
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
    #warning("tbc")
    return false
//    let stdin = try stdin
//      .then(readStdin())
//      .map(Execute.parseLines(reply:))
//      .get([])
//    let ctx = try worker.resolveParentReview(cfg: cfg)
//    try report(query: cfg.reportReviewCustom(
//      event: event,
//      review: ctx.review,
//      users: worker.resolveParticipants(
//        cfg: cfg,
//        gitlabCi: ctx.gitlab,
//        source: .make(sha: .init(value: ctx.job.pipeline.sha)),
//        target: .make(remote: .init(name: ctx.review.targetBranch))
//      ),
//      stdin: stdin))
//    return true
  }
  public func report(query: Report) -> Report.Reply {
    let token: String
    do { token = try query.cfg.slackToken.get() }
    catch { return logMessage(.init(message: "Report failed: \(error)")) }
    for signal in query.cfg.signals[query.context.identity].get([]) {
      let body: String
      do {
        body = try generate(query.generate(template: signal.body))
        guard !body.isEmpty else { continue }
      } catch {
        logMessage(.init(message: "Generate report error: \(error)"))
        continue
      }
      do { try Execute.checkStatus(reply: execute(query.cfg.curlSlack(
        token: token,
        method: signal.method,
        body: body
      ))) } catch {
        logMessage(.init(message: "Report delivery failed: \(error)"))
        logMessage(.init(message: body))
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
