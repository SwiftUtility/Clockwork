import Foundation
import Facility
public struct Execute: Query {
  public var input: Data? = nil
  public var tasks: [Task]
  public static func makeCurl(
    verbose: Bool,
    url: String,
    method: String = "GET",
    checkHttp: Bool = true,
    retry: UInt = 0,
    data: String? = nil,
    urlencode: [String] = [],
    form: [String] = [],
    headers: [String] = []
  ) -> Self {
    var arguments = ["curl", "--url", url]
    arguments += checkHttp.then(["--fail"]).or([])
    arguments += (retry > 0).then(["--retry", "\(retry)"]).or([])
    arguments += (method == "GET").else(["--request", method]).or([])
    arguments += headers.flatMap { ["--header", $0] }
    arguments += urlencode.flatMap { ["--data-urlencode", $0] }
    arguments += form.flatMap { ["--data", $0] }
    arguments += data.map { ["--data", $0] }.or([])
    return .init(tasks: [.init(escalate: checkHttp, verbose: verbose, arguments: arguments)])
  }
  public struct Task {
    public var launch: String = "/usr/bin/env"
    public var escalate: Bool = true
    public var environment: [String: String] = [:]
    public var verbose: Bool
    public var arguments: [String]
  }
  public struct Reply {
    public var data: Data?
    public var statuses: [Status]
    public init(data: Data? = nil, statuses: [Status]) {
      self.data = data
      self.statuses = statuses
    }
    public func checkStatus() throws {
      for status in statuses {
        guard status.task.escalate, status.termination != 0 else { continue }
        throw Thrown("Subprocess termination status")
      }
    }
    public struct Status {
      public var termination: Int32
      public var task: Task
      public init(termination: Int32, task: Task) {
        self.termination = termination
        self.task = task
      }
    }
  }
  public static func parseData(reply: Reply) throws -> Data {
    try reply.checkStatus()
    return reply.data.or(.init())
  }
  public static func parseText(reply: Reply) throws -> String {
    try reply.checkStatus()
    return try reply.data
      .map(String.make(utf8:))
      .or("")
      .trimmingCharacters(in: .newlines)
  }
  public static func parseLines(reply: Reply) throws -> [String] {
    try reply.checkStatus()
    return try reply.data
      .map(String.make(utf8:))
      .or("")
      .components(separatedBy: .newlines)
      .drop(while: \.isEmpty)
      .reversed()
      .drop(while: \.isEmpty)
      .reversed()
  }
  public static func parseSuccess(reply: Reply) throws -> Bool {
    if case nil = try? reply.checkStatus() { return false } else { return true }
  }
  public static func checkStatus(reply: Reply) throws { try reply.checkStatus() }
}
public extension Configuration {
  var systemTempFile: Execute { .init(tasks: [
    .init(verbose: verbose, arguments: ["mktemp"])
  ])}
  func systemMove(file: Files.Absolute, location: Files.Absolute) -> Execute { .init(tasks: [
    .init(verbose: verbose, arguments: ["mv", "-f", file.value, location.value])
  ])}
  func systemDelete(file: Files.Absolute) -> Execute { .init(tasks: [
    .init(escalate: false, verbose: verbose, arguments: ["rm", "-f", file.value])
  ])}
  func systemWrite(file: Files.Absolute, execute: Execute) -> Execute { .init(
    input: execute.input,
    tasks: execute.tasks + [.init(verbose: verbose, arguments: ["tee", file.value])]
  )}
  func curlSlackHook(url: String, payload: String) -> Execute { .makeCurl(
    verbose: verbose,
    url: url,
    method: "POST",
    retry: 2,
    urlencode: ["payload=\(payload)"]
  )}
  func write(file: Files.Absolute, execute: Execute) -> Execute {
    var execute = execute
    execute.tasks.append(.init(verbose: verbose, arguments: ["tee", file.value]))
    return execute
  }
}
public extension JSONDecoder {
  func decode<T: Decodable>(success: T.Type, reply: Execute.Reply) throws -> T {
    try reply.checkStatus()
    return try reply.data
      .reduce(success, decode(_:from:))
      .or { throw Thrown("Subprocess no output data") }
  }
}
