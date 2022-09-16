import Foundation
import Facility
public struct Slack {
  public var token: Lossy<String>
  public var hook: Lossy<String>
  public var signals: [String: [Signal]]
  public struct Signal {
    public var method: String?
    public var body: Configuration.Template
    public static func make(yaml: Yaml.Signal) throws -> Self { try .init(
      method: yaml.method,
      body: .make(yaml: yaml.body)
    )}
  }
}
