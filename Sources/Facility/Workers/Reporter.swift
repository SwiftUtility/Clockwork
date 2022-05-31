import Foundation
import Facility
import FacilityQueries
import FacilityAutomates
public struct Reporter {
  public var logLine: Act.Of<String>.Go
  public var printLine: Act.Of<String>.Go
  public var getTime: Act.Do<Date>
  public var renderStencil: Try.Reply<RenderStencil>
  public var handleSlackHook: Try.Reply<HandleSlackHook>
  public var formatter: DateFormatter
  public private(set) var issueCount: UInt = 0
  public init(
    logLine: @escaping Act.Of<String>.Go,
    printLine: @escaping Act.Of<String>.Go,
    getTime: @escaping Act.Do<Date>,
    renderStencil: @escaping Try.Reply<RenderStencil>,
    handleSlackHook: @escaping Try.Reply<HandleSlackHook>
  ) {
    self.logLine = logLine
    self.printLine = printLine
    self.getTime = getTime
    self.renderStencil = renderStencil
    self.handleSlackHook = handleSlackHook
    self.formatter = .init()
    formatter.dateFormat = "HH:mm:ss"
  }
  public func finish(cfg: Configuration, success: Bool) throws {
    if !success { throw Thrown("Execution considered unsuccessful") }
  }
  public func report(cfg: Configuration, error: Error) throws -> Bool {
    try? sendReport(query: .init(cfg: cfg, report: cfg.makeReport(error: error)))
    throw error
  }
  public func sendReport(query: SendReport) throws -> SendReport.Reply {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    for notification in query.cfg.notifications[query.report.name].or([]) {
      switch notification {
      case .slackHook(let slackHook): try Id
        .make(query.cfg.makeRenderStencil(
          context: query.report.makeContext(cfg: query.cfg),
          template: slackHook.template
        ))
        .map(renderStencil)
        .get()
        .map(slackHook.makePayload(text:))
        .map(encoder.encode(_:))
        .map(String.make(utf8:))
        .reduce(slackHook.url, HandleSlackHook.init(url:payload:))
        .map(handleSlackHook)
      case .jsonStdOut(let jsonStdOut): try Id
        .make(query.cfg.makeRenderStencil(
          context: query.report.makeContext(cfg: query.cfg),
          template: jsonStdOut.template
        ))
        .map(renderStencil)
        .get()
        .map { [query.report.name: $0] }
        .map(encoder.encode(_:))
        .map(String.make(utf8:))
        .map(printLine)
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
