import Foundation
import Facility
public struct PipeTask {
  public var launchPath: String
  public var environment: [String: String]
  public var surpassStdErr: Bool
  public var escalateFailure: Bool
  public var arguments: [String]
  public init(
    launchPath: String = "/usr/bin/env",
    environment: [String: String] = [:],
    surpassStdErr: Bool = false,
    escalateFailure: Bool = true,
    arguments: [String]
  ) {
    self.launchPath = launchPath
    self.environment = environment
    self.surpassStdErr = surpassStdErr
    self.escalateFailure = escalateFailure
    self.arguments = arguments
  }
  public var bash: String {
    ([launchPath] + arguments)
      .map { $0.replacingOccurrences(of: " ", with: #"\ "#) }
      .joined(separator: " ")
  }
  public static func makeCurl(
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
    return .init(surpassStdErr: true, escalateFailure: checkHttp, arguments: arguments)
  }
}
