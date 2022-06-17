import Foundation
import Facility
import FacilityPure
public struct Requisitor {
  let execute: Try.Reply<Execute>
  let resolveAbsolute: Try.Reply<Files.ResolveAbsolute>
  let resolveRequisition: Try.Reply<Configuration.ResolveRequisition>
  let resolveSecret: Try.Reply<Configuration.ResolveSecret>
  let getTime: Act.Do<Date>
  let getUuid: Act.Do<UUID>
  let plistDecoder: PropertyListDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveAbsolute: @escaping Try.Reply<Files.ResolveAbsolute>,
    resolveRequisition: @escaping Try.Reply<Configuration.ResolveRequisition>,
    resolveSecret: @escaping Try.Reply<Configuration.ResolveSecret>,
    getTime: @escaping Act.Do<Date>,
    getUuid: @escaping Act.Do<UUID>,
    plistDecoder: PropertyListDecoder
  ) {
    self.execute = execute
    self.resolveAbsolute = resolveAbsolute
    self.resolveRequisition = resolveRequisition
    self.resolveSecret = resolveSecret
    self.getTime = getTime
    self.getUuid = getUuid
    self.plistDecoder = plistDecoder
  }
  public func importProvisions(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    let requisition = try resolveRequisition(.init(cfg: cfg))
    try requisites
      .flatMap { try getProvisions(git: cfg.git, requisition: requisition, requisite: $0)}
      .forEach { try install(cfg: cfg, requisition: requisition, provision: $0) }
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
      .forEach { try install(cfg: cfg, requisition: requisition, provision: $0) }
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
    let requisition = try resolveRequisition(.init(cfg: cfg))
    let threshold = getTime().advanced(by: .init(days) * .day)
    var items: [Report.ExpiringRequisites.Item] = []
    let provisions: Set<Git.File> = try requisition.requisites.keys
      .map { try getProvisions(git: cfg.git, requisition: requisition, requisite: $0) }
      .reduce([]) { $0.union($1) }
    for file in provisions {
      let temp = try Id(cfg.systemTempFile)
        .map(execute)
        .map(String.make(utf8:))
        .map(Files.Absolute.init(value:))
        .get()
      defer { _ = try? execute(cfg.systemDelete(file: temp)) }
      _ = try Id(file)
        .map(cfg.git.cat(file:))
        .reduce(temp, cfg.systemWrite(file:execute:))
        .map(execute)
      let provision = try Id(temp)
        .map(requisition.decode(file:))
        .map(execute)
        .reduce(Plist.Provision.self, plistDecoder.decode(_:from:))
        .get()
      guard provision.expirationDate < threshold else { continue }
      let days = min(0, Int(threshold.timeIntervalSince(provision.expirationDate) / .day))
      items.append(.init(file: file.path.value, name: provision.name, days: "\(days)"))
    }
    let keychain = getUuid().uuidString
    for (key, requisite) in requisition.requisites {
      _ = try execute(requisition.create(keychain: keychain))
      defer { _ = try? execute(requisition.delete(keychain: keychain)) }
      _ = try execute(requisition.unlock(keychain: keychain))
      try importKeychain(cfg: cfg, requisition: requisition, requisite: key, keychain: keychain)
      let certs = try Id(keychain)
        .map(requisition.exportCerts(keychain:))
        .map(execute)
        .map(String.make(utf8:))
        .get()
        .components(separatedBy: .newlines)
        .split(separator: .certStart)
        .map { ([.certStart] + $0)
          .map { $0 + "\n" }
          .joined()
          .utf8
        }
        .map(Data.init(_:))
      for cert in certs {
        let lines = try Id(cert)
          .map(requisition.readCertDetails(data:))
          .map(execute)
          .map(String.make(utf8:))
          .get()
          .components(separatedBy: .newlines)
          .map { $0.trimmingCharacters(in: .whitespaces) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d HH:mm:ss yyyy zzz"
        let date = try lines
          .compactMap { try? $0.dropPrefix("notAfter=") }
          .first
          .flatMap(formatter.date(from:))
          .or { throw MayDay("openssl output") }
        guard date < threshold else { continue }
        let escaped = try lines
          .compactMap { try? $0.dropPrefix("commonName") }
          .first
          .or { throw MayDay("openssl output") }
          .trimmingCharacters(in: .newlines)
          .dropPrefix("= ")
          .replacingOccurrences(of: "\\U", with: "\\u")
        let name = NSMutableString(string: escaped)
        CFStringTransform(name, nil, "Any-Hex/Java" as NSString, true)
        let days = min(0, Int(threshold.timeIntervalSince(date) / .day))
        items.append(.init(
          file: requisite.pkcs12.path.value,
          name: name as String,
          days: "\(days)")
        )
      }
    }
    return true
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
    let requisite = try requisition.requisite(name: requisite)
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
  ) throws -> Set<Git.File> {
    var result: Set<Git.File> = []
    for dir in try requisition.requisite(name: requisite).provisions { try Id(dir)
      .map(git.listTreeTrackedFiles(dir:))
      .map(execute)
      .map(String.make(utf8:))
      .get()
      .components(separatedBy: .newlines)
      .map(Files.Relative.init(value:))
      .forEach { result.insert(.init(ref: dir.ref, path: $0)) }
    }
    return result
  }
  func install(cfg: Configuration, requisition: Requisition, provision: Git.File) throws {
    let temp = try Id(cfg.systemTempFile)
      .map(execute)
      .map(String.make(utf8:))
      .map(Files.Absolute.init(value:))
      .get()
    defer { _ = try? execute(cfg.systemDelete(file: temp)) }
    _ = try Id(provision)
      .map(cfg.git.cat(file:))
      .reduce(temp, cfg.systemWrite(file:execute:))
      .map(execute)
    _ = try Id(temp)
      .map(requisition.decode(file:))
      .map(execute)
      .reduce(Plist.Provision.self, plistDecoder.decode(_:from:))
      .map(\.uuid)
      .map { "~/Library/MobileDevice/Provisioning Profiles/\($0).mobileprovision" }
      .map(Files.ResolveAbsolute.make(path:))
      .map(resolveAbsolute)
      .reduce(temp, cfg.systemMove(file:location:))
      .map(execute)
  }
}
extension TimeInterval {
  static var day: Self { 24 * 60 * 60 }
}
extension String {
  static var certStart: Self { "-----BEGIN CERTIFICATE-----" }
}
