import Foundation
import Facility
public struct Requisition {
  public var verbose: Bool
  public var keychains: [String: Keychain]
  public var provisions: [String: Git.Dir]
  public static func make(
    verbose: Bool,
    ref: Git.Ref,
    yaml: Yaml.Controls.Requisition
  ) throws -> Self { try .init(
    verbose: verbose,
    keychains: yaml.keychains
      .mapValues { yaml in try .init(
        pkcs12: yaml.pkcs12,
        password: .init(yaml: yaml.password)
      )},
    provisions: yaml.provisions
      .mapValues { try .init(
        ref: ref,
        path: .init(value: $0)
      )}
  )}
  public struct Keychain {
    public var pkcs12: String
    public var password: Secret
  }
}
public extension Requisition {
  func decode(file: Files.Absolute) -> Execute { proc(args: ["cms", "-D", "-i", file.value]) }
  func delete(keychain: String) -> Execute { proc(
    args: ["delete-keychain", keychain]
  )}
  func create(keychain: String) -> Execute { proc(
    args: ["create-keychain", "-p", "", keychain]
  )}
  func unlock(keychain: String) -> Execute { proc(
    args: ["unlock-keychain", "-p", "", keychain]
  )}
  func disableAutolock(keychain: String) -> Execute { proc(
    args: ["set-keychain-settings", keychain]
  )}
  var listVisibleKeychains: Execute { proc(args: ["list-keychains", "-d", "user"]) }
  func resetVisibleKeychains(keychains: [String]) -> Execute { proc(
    args: ["list-keychains", "-d", "user", "-s"] + keychains
  )}
  func importPkcs12(
    keychain: String,
    file: Files.Absolute,
    pass: String
  ) -> Execute { proc(
    args: ["import", file.value, "-k", keychain, "-P", pass]
    + ["-t" ,"priv", "-T", "/usr/bin/codesign", "-f", "pkcs12"]
  )}
  func leaseXcode(keychain: String) -> Execute { proc(
    args: ["set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", "", keychain]
  )}
}
extension Requisition {
  func proc(args: [String]) -> Execute {
    .init(tasks: [.init(verbose: verbose, arguments: ["security"] + args)])
  }
}
