import Foundation
import Facility
import FacilityQueries
import FacilityAutomates
public struct Reporter {
  let execute: Try.Reply<Execute>
  let logLine: Act.Of<String>.Go
  let printLine: Act.Of<String>.Go
  let getTime: Act.Do<Date>
  let renderStencil: Try.Reply<RenderStencil>
  let formatter: DateFormatter
  public init(
    execute: @escaping Try.Reply<Execute>,
    logLine: @escaping Act.Of<String>.Go,
    printLine: @escaping Act.Of<String>.Go,
    getTime: @escaping Act.Do<Date>,
    renderStencil: @escaping Try.Reply<RenderStencil>
  ) {
    self.execute = execute
    self.logLine = logLine
    self.printLine = printLine
    self.getTime = getTime
    self.renderStencil = renderStencil
    self.formatter = .init()
    formatter.dateFormat = "HH:mm:ss"
  }
  public func finish(cfg: Configuration, success: Bool) throws {
    if !success { throw Thrown("Execution considered unsuccessful") }
  }
  public func report(cfg: Configuration, error: Error) throws -> Bool {
    try? Id(error)
      .map(cfg.reportUnexpected(error:))
      .map(cfg.makeSendReport(report:))
      .map(sendReport(query:))
      .get()
    throw error
  }
  public func sendReport(query: SendReport) throws -> SendReport.Reply {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    for value in query.cfg.controls.communication[query.report.event].or([]) {
      switch value {
      case .slackHookTextMessage(let value): _ = try Id
        .make(query.cfg.controls.makeRenderStencil(
          template: value.messageTemplate,
          context: query.report.context
        ))
        .map(renderStencil)
        .map(value.makePayload(text:))
        .map(encoder.encode(_:))
        .map(String.make(utf8:))
        .reduce(value.url, query.cfg.curlSlackHook(url:payload:))
        .map(execute)
      }
    }
  }
  public func logMessage(query: LogMessage) -> LogMessage.Reply { log(message: query.message) }
}
private extension Reporter {
  func merge(context: inout [String: AnyCodable], element: AnyCodable) throws {
    guard let element = element.map else { throw MayDay("wrong encodable structure") }
    try context.merge(element) { _,_ in throw MayDay("not unique unique") }
  }
  func log(message: String) { message
    .split(separator: "\n")
    .compactMap { line in line.isEmpty.else("[\(formatter.string(from: getTime()))]: \(line)") }
    .forEach(logLine)
  }
}
