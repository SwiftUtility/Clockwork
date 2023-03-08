import Foundation
import Facility
public struct Requisition {
  public var branch: Ctx.Git.Branch
  public var keychain: Keychain
  public var requisites: [String: Requisite]
  public func requisite(name: String) throws -> Requisite {
    try requisites[name].get { throw Thrown("No \(name) in requisition") }
  }
  public static func make(
    yaml: Yaml.Requisition
  ) throws -> Self { try .init(
    branch: .make(name: yaml.branch),
    keychain: .init(name: yaml.keychain.name, password: .make(yaml: yaml.keychain.password)),
    requisites: yaml.requisites.mapValues(Requisite.make(yaml:))
  )}
  public struct Keychain {
    public var name: String
    public var password: Ctx.Secret
  }
  public struct Requisite {
    public var pkcs12: Ctx.Sys.Relative
    public var password: Ctx.Secret
    public var provisions: [Ctx.Sys.Relative]
    public static func make(
      yaml: Yaml.Requisition.Requisite
    ) throws -> Self { try .init(
      pkcs12: .make(value: yaml.pkcs12),
      password: .make(yaml: yaml.password),
      provisions: yaml.provisions.map(Ctx.Sys.Relative.init(value:))
    )}
  }
}
