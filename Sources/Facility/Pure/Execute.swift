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
    return .init(tasks: [.init(escalate: checkHttp, verbose: verbose, arguments: arguments)])
  }
  public struct Task {
    public var launch: String = "/usr/bin/env"
    public var escalate: Bool = true
    public var environment: [String: String] = [:]
    public var verbose: Bool
    public var arguments: [String]
  }
  public typealias Reply = Data
}
public extension Configuration {
  var systemTempFile: Execute { .init(tasks: [
    .init(verbose: verbose, arguments: ["mktemp"])
  ])}
  func systemMove(file: Files.Absolute, location: Files.Absolute) -> Execute { .init(tasks: [
    .init(verbose: verbose, arguments: ["mv", "-f", file.value, location.value])
  ])}
  func systemDelete(file: Files.Absolute) -> Execute { .init(tasks: [
    .init(verbose: verbose, arguments: ["rm", "-f", file.value])
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
