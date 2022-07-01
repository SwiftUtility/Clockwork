import Foundation
import Facility
import FacilityPure
public final class Reporter {
  let execute: Try.Reply<Execute>
  let writeStderr: Act.Of<String>.Go
  let writeStdout: Act.Of<String>.Go
  let getTime: Act.Do<Date>
  let readStdin: Try.Do<Execute.Reply>
  let generate: Try.Reply<Generate>
  let jsonDecoder: JSONDecoder
  let formatter: DateFormatter
  public init(
    execute: @escaping Try.Reply<Execute>,
    writeStderr: @escaping Act.Of<String>.Go,
    writeStdout: @escaping Act.Of<String>.Go,
    getTime: @escaping Act.Do<Date>,
    readStdin: @escaping Try.Do<Execute.Reply>,
    generate: @escaping Try.Reply<Generate>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.writeStderr = writeStderr
    self.writeStdout = writeStdout
    self.getTime = getTime
    self.readStdin = readStdin
    self.generate = generate
    self.jsonDecoder = jsonDecoder
    self.formatter = .init()
    formatter.dateFormat = "HH:mm:ss"
  }
  public func finish(cfg: Configuration, success: Bool) throws {
    if !success { throw Thrown("Execution considered unsuccessful") }
  }
  public func report(cfg: Configuration, error: Error) throws -> Bool {
    try? Id(error)
      .map(cfg.reportUnexpected(error:))
      .map(report(query:))
      .get()
    throw error
  }
  public func reportCustom(cfg: Configuration, event: String, stdin: Bool) throws -> Bool {
    let stdin = try stdin
      .then(readStdin())
      .map(Execute.parseLines(reply:))
      .get([])
    try report(query: cfg.reportCustom(event: event, stdin: stdin))
    return true
  }
  public func report(query: Report) throws -> Report.Reply {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    for value in query.cfg.controls.communication[query.context.event].get([]) {
      switch value {
      case .slackHookTextMessage(let value):
        let message = try generate(query.generate(template: value.createMessageText))
          .debug()
        guard !message.isEmpty else { continue }
        try Id(message)
        .map(value.makePayload(text:))
        .map(encoder.encode(_:))
        .map(String.make(utf8:))
        .reduce(value.url, query.cfg.curlSlackHook(url:payload:))
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
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
    .forEach(writeStderr)
  }
}
