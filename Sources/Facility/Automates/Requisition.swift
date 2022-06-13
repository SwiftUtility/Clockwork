import Foundation
import Facility
public struct Requisition {
  public var keychainName: String
  public var keychainFiles: [String: Keychain]
  public var provisions: [String: Git.Dir]
  public static func make(
    ref: Git.Ref,
    yaml: Yaml.Controls.Requisition
  ) throws -> Self { try .init(
    keychainName: yaml.keychainName,
    keychainFiles: yaml.keychainFiles
      .mapValues { yaml in try .init(
        crypto: yaml.crypto,
        password: .init(yaml: yaml.password)
      )},
    provisions: yaml.provisions
      .mapValues { try .init(
        ref: ref,
        path: .init(value: $0)
      )}
  )}
  public struct Keychain {
    public var crypto: String
    public var password: Token
  }
}
