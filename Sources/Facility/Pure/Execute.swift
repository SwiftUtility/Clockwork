import Foundation
import Facility
public struct Execute: Query {
  public var input: Data? = nil
  public var tasks: [Task]
  public static func makeCurl(
    url: String,
    method: String = "GET",
    checkHttp: Bool = true,
    retry: UInt = 0,
    data: String? = nil,
    urlencode: [String] = [],
    form: [String] = [],
    headers: [String] = [],
    secrets: [String]
  ) -> Self {
    var arguments = ["curl", "--url", url]
    arguments += checkHttp.then(["--fail"]).get([])
    arguments += (retry > 0).then(["--retry", "\(retry)"]).get([])
    arguments += (method == "GET").else(["--request", method]).get([])
    arguments += headers.flatMap { ["--header", $0] }
    arguments += urlencode.flatMap { ["--data-urlencode", $0] }
    arguments += form.flatMap { ["--data", $0] }
    arguments += data.map { ["--data", $0] }.get([])
    return .init(tasks: [.init(
      escalate: checkHttp,
      environment: [:],
      arguments: arguments,
      secrets: secrets
    )])
  }
  public struct Task {
    public var launch: String = "/usr/bin/env"
    public var escalate: Bool = true
    public var environment: [String: String]
    public var arguments: [String]
    public var secrets: [String]
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
        let launch = ["\(status.termination): \(status.task.launch)\n"]
        + status.task.arguments.map { "  \($0)\n" }
        var message = launch.joined() + status.stderr
          .flatMap { String(data: $0, encoding: .utf8) }
          .get("")
        for secret in status.task.secrets {
          message = message.replacingOccurrences(of: secret, with: "[MASKED]")
        }
        throw Thrown(message)
      }
    }
    public struct Status {
      public var task: Task
      public var stderr: Data?
      public var termination: Int32
      public init(task: Task, stderr: Data?, termination: Int32) {
        self.task = task
        self.stderr = stderr
        self.termination = termination
      }
    }
  }
  public static func parseData(reply: Reply) throws -> Data {
    try reply.checkStatus()
    return reply.data.get(.init())
  }
  public static func parseText(reply: Reply) throws -> String {
    try reply.checkStatus()
    return try reply.data
      .map(String.make(utf8:))
      .get("")
      .trimmingCharacters(in: .newlines)
  }
  public static func parseLines(reply: Reply) throws -> [String] {
    try reply.checkStatus()
    return try reply.data
      .map(String.make(utf8:))
      .get("")
      .components(separatedBy: .newlines)
      .drop(while: \.isEmpty)
      .reversed()
      .drop(while: \.isEmpty)
      .reversed()
  }
  public static func parseSuccess(reply: Reply) -> Bool {
    if case nil = try? reply.checkStatus() { return false } else { return true }
  }
  public static func checkStatus(reply: Reply) throws { try reply.checkStatus() }
}
public extension Configuration {
  var systemTempFile: Execute { .init(tasks: [
    .init(environment: env, arguments: ["mktemp"], secrets: [])
  ])}
  func createDir(path: Files.Absolute) -> Execute { .init(tasks: [
    .init(environment: env, arguments: ["mkdir", "-p", path.value], secrets: [])
  ])}
  func systemMove(file: Files.Absolute, location: Files.Absolute) -> Execute { .init(tasks: [
    .init(environment: env, arguments: ["mv", "-f", file.value, location.value], secrets: [])
  ])}
  func systemDelete(path: Files.Absolute) -> Execute { .init(tasks: [
    .init(escalate: false, environment: env, arguments: ["rm", "-rf", path.value], secrets: [])
  ])}
  func systemWrite(file: Files.Absolute, execute: Execute) -> Execute { .init(
    input: execute.input,
    tasks: execute.tasks + [.init(environment: env, arguments: ["tee", file.value], secrets: [])]
  )}
  func curlSlack(token: String, method: String, body: String) throws -> Execute { .makeCurl(
    url: "https://slack.com/api/\(method)",
    method: "POST",
    retry: 2,
    data: body,
    headers: [Json.utf8, "Authorization: Bearer \(token)"],
    secrets: [token]
  )}
  func write(file: Files.Absolute, execute: Execute) -> Execute {
    var execute = execute
    execute.tasks.append(.init(environment: env, arguments: ["tee", file.value], secrets: []))
    return execute
  }
  func podAddSpec(name: String, url: String) -> Execute { .init(tasks: [
    .init(
      environment: env,
      arguments: ["bundle", "exec", "pod", "repo", "add", name, url],
      secrets: []
    )
  ])}
  func podUpdateSpec(name: String) -> Execute { .init(tasks: [
    .init(
      environment: env,
      arguments: ["bundle", "exec", "pod", "repo", "update", name],
      secrets: []
    )
  ])}
}
public extension JSONDecoder {
  func decode<T: Decodable>(success: T.Type, reply: Execute.Reply) throws -> T {
    try reply.checkStatus()
    return try reply.data
      .reduce(success, decode(_:from:))
      .get { throw Thrown("Subprocess no output data") }
  }
}
