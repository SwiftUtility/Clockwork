import Foundation
import Facility
public struct Requisition {
  public var env: [String: String]
  public var branch: Git.Branch
  public var keychain: Keychain
  public var requisites: [String: Requisite]
  public func requisite(name: String) throws -> Requisite {
    try requisites[name].get { throw Thrown("No \(name) in requisition") }
  }
  public static func make(
    env: [String: String],
    yaml: Yaml.Requisition
  ) throws -> Self { try .init(
    env: env,
    branch: .make(name: yaml.branch),
    keychain: .init(name: yaml.keychain.name, password: .make(yaml: yaml.keychain.password)),
    requisites: yaml.requisites.mapValues(Requisite.make(yaml:))
  )}
  public struct Keychain {
    public var name: String
    public var password: Configuration.Secret
  }
  public struct Requisite {
    public var pkcs12: Files.Relative
    public var password: Configuration.Secret
    public var provisions: [Files.Relative]
    public static func make(
      yaml: Yaml.Requisition.Requisite
    ) throws -> Self { try .init(
      pkcs12: .init(value: yaml.pkcs12),
      password: .make(yaml: yaml.password),
      provisions: yaml.provisions.map(Files.Relative.init(value:))
    )}
  }
}
public extension Requisition {
  func decode(file: Files.Absolute) -> Execute { proc(
    args: ["security", "cms", "-D", "-i", file.value]
  )}
  var deleteKeychain: Execute { proc(
    args: ["security", "delete-keychain", keychain.name],
    escalate: false
  )}
  func createKeychain(password: String) -> Execute { proc(
    args: ["security", "create-keychain", "-p", password, keychain.name]
  )}
  func unlockKeychain(password: String) -> Execute { proc(
    args: ["security", "unlock-keychain", "-p", password, keychain.name]
  )}
  var disableKeychainAutolock: Execute { proc(
    args: ["security", "set-keychain-settings", keychain.name]
  )}
  var listVisibleKeychains: Execute { proc(
    args: ["security", "list-keychains", "-d", "user"]
  )}
  func resetVisible(keychains: [String]) -> Execute { proc(
    args: ["security", "list-keychains", "-d", "user", "-s"] + keychains
  )}
  func importPkcs12(
    file: Files.Absolute,
    password: String
  ) -> Execute { proc(
    args: ["security", "import", file.value, "-k", keychain.name, "-P", password]
    + ["-T", "/usr/bin/codesign", "-f", "pkcs12"]
  )}
  var allowXcodeAccessKeychain: Execute { proc(
    args: ["security", "set-key-partition-list"]
    + ["-S", "apple-tool:,apple:,codesign:"]
    + ["-s", "-k", "", keychain.name]
  )}
  func parsePkcs12Certs(
    password: String,
    execute: Execute
  ) -> Execute {
    var result = execute
    result.tasks += proc(
      args: ["openssl", "pkcs12", "-passin", "pass:\(password)", "-passout", "pass:"]
    ).tasks
    return result
  }
  func decodeCert(
    data: Data
  ) -> Execute { proc(
    args: ["openssl", "x509", "-enddate", "-subject", "-noout", "-nameopt", "multiline"],
    input: data
  )}
}
extension Requisition {
  func proc(
    args: [String],
    input: Data? = nil,
    escalate: Bool = true
  ) -> Execute { .init(input: input, tasks: [.init(
    escalate: escalate,
    environment: self.env,
    arguments: args,
    secrets: []
  )])}
}
