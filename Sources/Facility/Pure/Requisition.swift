import Foundation
import Facility
public struct Requisition {
  public var verbose: Bool
  public var requisites: [String: Requisite]
  public func requisite(name: String) throws -> Requisite {
    try requisites[name].or { throw Thrown("No \(name) in requisition") }
  }
  public static func make(
    verbose: Bool,
    ref: Git.Ref,
    yaml: [String: Yaml.Controls.Requisition]
  ) throws -> Self { try .init(
    verbose: verbose,
    requisites: yaml
      .mapValues { try .make(ref: ref, yaml: $0) }
  )}
  public struct Requisite {
    public var pkcs12: Git.File
    public var password: Secret
    public var provisions: [Git.Dir]
    public static func make(
      ref: Git.Ref,
      yaml: Yaml.Controls.Requisition
    ) throws -> Self { try .init(
      pkcs12: .init(
        ref: .make(remote: .init(name: yaml.pkcs12.branch)),
        path: .init(value: yaml.pkcs12.path)
      ),
      password: .init(yaml: yaml.password),
      provisions: yaml.provisions.map { yaml in try .init(
        ref: ref,
        path: .init(value: yaml)
      )}
    )}
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
  func exportCerts(
    keychain: String
  ) -> Execute { proc(args: ["find-certificate", "-a", "-p", keychain]) }
  func leaseXcode(keychain: String) -> Execute { proc(
    args: ["set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s", "-k", "", keychain]
  )}
  func readCertDetails(
    data: Data
  ) -> Execute { proc(
    args: ["openssl", "x509", "-enddate", "-subject", "-noout", "-nameopt", "multiline"],
    input: data
  )}
}
extension Requisition {
  func proc(
    args: [String],
    input: Data? = nil
  ) -> Execute {
    .init(input: input, tasks: [.init(verbose: verbose, arguments: ["security"] + args)])
  }
}
