import Foundation
import Facility
public struct Slack {
  public var token: String
  public var signals: [String: [Signal]]
  public static func make(
    token: String,
    signals: [String: [Yaml.Signal]]
  ) throws -> Self { try .init(
    token: token,
    signals: signals
      .mapValues { try $0.map(Signal.make(yaml:)) }
  )}
  public struct Signal {
    public var method: String
    public var body: Configuration.Template
    public static func make(yaml: Yaml.Signal) throws -> Self { try .init(
      method: yaml.method,
      body: .make(yaml: yaml.body)
    )}
  }
}
