import Foundation
import Facility
import FacilityPure
public struct Requisitor {
  let execute: Try.Reply<Execute>
  let resolveAbsolute: Try.Reply<Files.ResolveAbsolute>
  let resolveRequisition: Try.Reply<Configuration.ResolveRequisition>
  let resolveSecret: Try.Reply<Configuration.ResolveSecret>
  let plistDecoder: PropertyListDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveAbsolute: @escaping Try.Reply<Files.ResolveAbsolute>,
    resolveRequisition: @escaping Try.Reply<Configuration.ResolveRequisition>,
    resolveSecret: @escaping Try.Reply<Configuration.ResolveSecret>,
    plistDecoder: PropertyListDecoder
  ) {
    self.execute = execute
    self.resolveAbsolute = resolveAbsolute
    self.resolveRequisition = resolveRequisition
    self.resolveSecret = resolveSecret
    self.plistDecoder = plistDecoder
  }
  public func importProvisions(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    let requisition = try resolveRequisition(.init(cfg: cfg))
    try requisites
      .flatMap { try getProvisions(git: cfg.git, requisition: requisition, requisite: $0)}
      .forEach { try install(cfg: cfg, provision: $0) }
    return true
  }
  public func importKeychains(
    cfg: Configuration,
    keychain: String,
    requisites: [String]
  ) throws -> Bool {
    let requisition = try resolveRequisition(.init(cfg: cfg))
    try cleanKeychain(cfg: cfg, requisition: requisition, keychain: keychain)
    try requisites.forEach {
      try importKeychain(cfg: cfg, requisition: requisition, requisite: $0, keychain: keychain)
    }
    _ = try execute(requisition.leaseXcode(keychain: keychain))
    return true
  }
  public func importRequisites(
    cfg: Configuration,
    keychain: String,
    requisites: [String]
  ) throws -> Bool {
    let requisition = try resolveRequisition(.init(cfg: cfg))
    try requisites
      .flatMap { try getProvisions(git: cfg.git, requisition: requisition, requisite: $0)}
      .forEach { try install(cfg: cfg, provision: $0) }
    try cleanKeychain(cfg: cfg, requisition: requisition, keychain: keychain)
    try requisites.forEach {
      try importKeychain(cfg: cfg, requisition: requisition, requisite: $0, keychain: keychain)
    }
    _ = try execute(requisition.leaseXcode(keychain: keychain))
    return true
  }
  public func reportExpiringRequisites(
    cfg: Configuration,
    days: UInt
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  func cleanKeychain(
    cfg: Configuration,
    requisition: Requisition,
    keychain: String
  ) throws {
    _ = try execute(requisition.delete(keychain: keychain))
    _ = try execute(requisition.create(keychain: keychain))
    _ = try execute(requisition.unlock(keychain: keychain))
    _ = try execute(requisition.disableAutolock(keychain: keychain))
    let keychains = try Id(requisition.listVisibleKeychains)
      .map(execute)
      .map(String.make(utf8:))
      .get()
      .components(separatedBy: .newlines)
      .map { $0.trimmingCharacters(in: .whitespaces.union(["\""])) }
    _ = try execute(requisition.resetVisibleKeychains(keychains: keychains + [keychain]))
  }
  func importKeychain(
    cfg: Configuration,
    requisition: Requisition,
    requisite: String,
    keychain: String
  ) throws {
    let requisite = try requisition.keychains[requisite]
      .or { throw Thrown("No \(requisite) in keychains") }
    let password = try resolveSecret(.init(cfg: cfg, secret: requisite.password))
    let temp = try Id(cfg.systemTempFile)
      .map(execute)
      .map(String.make(utf8:))
      .map(Files.Absolute.init(value:))
      .get()
    defer { _ = try? execute(cfg.systemDelete(file: temp)) }
    _ = try Id(requisite.pkcs12)
      .map(cfg.git.cat(file:))
      .reduce(temp, cfg.write(file:execute:))
      .map(execute)
    _ = try execute(requisition.importPkcs12(keychain: keychain, file: temp, pass: password))
  }
  func getProvisions(
    git: Git,
    requisition: Requisition,
    requisite: String
  ) throws -> [Git.File] {
    let dir = try requisition.provisions[requisite]
      .or { throw Thrown("No \(requisite) in provisions") }
    return try Id(dir)
      .map(git.listTreeTrackedFiles(dir:))
      .map(execute)
      .map(String.make(utf8:))
      .get()
      .components(separatedBy: .newlines)
      .map(Files.Relative.init(value:))
      .map { .init(ref: dir.ref, path: $0) }
  }
  func install(cfg: Configuration, provision: Git.File) throws {
    let requisition = try resolveRequisition(.init(cfg: cfg))
    let temp = try Id(cfg.systemTempFile)
      .map(execute)
      .map(String.make(utf8:))
      .map(Files.Absolute.init(value:))
    _ = try Id(provision)
      .map(cfg.git.cat(file:))
      .reduce(temp.get(), cfg.systemWrite(file:execute:))
      .map(execute)
    _ = try temp
      .map(requisition.decode(file:))
      .map(execute)
      .reduce(Plist.Provision.self, plistDecoder.decode(_:from:))
      .map(\.uuid)
      .map { "~/Library/MobileDevice/Provisioning Profiles/\($0).mobileprovision" }
      .map(Files.ResolveAbsolute.make(path:))
      .map(resolveAbsolute)
      .reduce(temp.get(), cfg.systemMove(file:location:))
      .map(execute)
  }
}
