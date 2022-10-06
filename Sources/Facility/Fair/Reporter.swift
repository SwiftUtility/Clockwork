import Foundation
import Facility
import FacilityPure
public final class Reporter {
  let execute: Try.Reply<Execute>
  let writeStdout: Act.Of<String>.Go
  let readStdin: Try.Do<Execute.Reply>
  let generate: Try.Reply<Generate>
  let resolveFusion: Try.Reply<Configuration.ResolveFusion>
  let resolveFusionStatuses: Try.Reply<Configuration.ResolveFusionStatuses>
  let resolveApprovers: Try.Reply<Configuration.ResolveApprovers>
  let logMessage: Act.Reply<LogMessage>
  let worker: Worker
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    writeStdout: @escaping Act.Of<String>.Go,
    readStdin: @escaping Try.Do<Execute.Reply>,
    generate: @escaping Try.Reply<Generate>,
    resolveFusion: @escaping Try.Reply<Configuration.ResolveFusion>,
    resolveFusionStatuses: @escaping Try.Reply<Configuration.ResolveFusionStatuses>,
    resolveApprovers: @escaping Try.Reply<Configuration.ResolveApprovers>,
    logMessage: @escaping Act.Reply<LogMessage>,
    worker: Worker,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.writeStdout = writeStdout
    self.readStdin = readStdin
    self.generate = generate
    self.resolveFusion = resolveFusion
    self.resolveFusionStatuses = resolveFusionStatuses
    self.resolveApprovers = resolveApprovers
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
    let slack = try query.report.cfg.slack.get()
    let body = try generate(query.report.generate(template: query.template))
    let data = try Execute.parseData(reply: execute(query.report.cfg.curlSlack(
      token: slack.token,
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
    let fusion = try resolveFusion(.init(cfg: cfg))
    let ctx = try worker.resolveParentReview(cfg: cfg)
    let stdin = try stdin
      .then(readStdin())
      .map(Execute.parseLines(reply:))
      .get([])
    let statuses = try resolveFusionStatuses(.init(cfg: cfg, approval: fusion.approval))
    guard let status = statuses[ctx.review.iid] else { throw Thrown("No review thread") }
    let approvers = try resolveApprovers(.init(cfg: cfg, approval: fusion.approval))
    #warning("tbc")
    return false
    try report(query: cfg.reportReviewCustom(
      event: event,
      status: status,
      approvers: approvers,
      state: ctx.review,
      stdin: stdin
    ))
    return true
  }
  public func report(query: Report) -> Report.Reply {
    let slack: Slack
    do { slack = try query.cfg.slack.get() }
    catch { return logMessage(.init(message: "Report failed: \(error)")) }
    for signal in slack.signals[query.context.identity].get([]) {
      let body: String
      do {
        body = try generate(query.generate(template: signal.body))
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
private extension Reporter {
  func merge(context: inout [String: AnyCodable], element: AnyCodable) throws {
    guard let element = element.map else { throw MayDay("wrong encodable structure") }
    try context.merge(element) { _,_ in throw MayDay("not unique unique") }
  }
}
