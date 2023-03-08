import Foundation
import Facility
import FacilityPure
public final class Requisitor {
  let execute: Try.Reply<Execute>
  let resolveAbsolute: Try.Reply<Files.ResolveAbsolute>
  let parseRequisition: Try.Reply<ParseYamlFile<Requisition>>
  let resolveSecret: Try.Reply<Configuration.ResolveSecret>
  let parseCocoapods: Try.Reply<ParseYamlFile<Cocoapods>>
  let writeFile: Try.Reply<Files.WriteFile>
  let listFileSystem: Try.Reply<Files.ListFileSystem>
  let getTime: Act.Do<Date>
  let plistDecoder: PropertyListDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveAbsolute: @escaping Try.Reply<Files.ResolveAbsolute>,
    parseRequisition: @escaping Try.Reply<ParseYamlFile<Requisition>>,
    resolveSecret: @escaping Try.Reply<Configuration.ResolveSecret>,
    parseCocoapods: @escaping Try.Reply<ParseYamlFile<Cocoapods>>,
    writeFile: @escaping Try.Reply<Files.WriteFile>,
    listFileSystem: @escaping Try.Reply<Files.ListFileSystem>,
    getTime: @escaping Act.Do<Date>,
    plistDecoder: PropertyListDecoder
  ) {
    self.execute = execute
    self.resolveAbsolute = resolveAbsolute
    self.parseRequisition = parseRequisition
    self.resolveSecret = resolveSecret
    self.parseCocoapods = parseCocoapods
    self.writeFile = writeFile
    self.listFileSystem = listFileSystem
    self.getTime = getTime
    self.plistDecoder = plistDecoder
  }
  public func installProvisions(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    let requisition = try cfg.parseRequisition.map(parseRequisition).get()
    let requisites = requisites.isEmpty
      .else(requisites)
      .get(.init(requisition.requisites.keys))
    try prepareProvisions(cfg: cfg)
    try getProvisions(git: cfg.git, requisition: requisition, requisites: requisites)
      .forEach { try install(cfg: cfg, requisition: requisition, provision: $0) }
    return true
  }
  public func installKeychain(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    let requisition = try cfg.parseRequisition.map(parseRequisition).get()
    let password = try resolveSecret(.init(cfg: cfg, secret: requisition.keychain.password))
    try cleanKeychain(cfg: cfg, requisition: requisition, password: password)
    try requisites.isEmpty
      .else(requisites)
      .get(.init(requisition.requisites.keys))
      .forEach { requisite in try importKeychain(
        cfg: cfg,
        requisition: requisition,
        requisite: requisition.requisite(name: requisite)
      )}
    try Execute.checkStatus(reply: execute(requisition.allowXcodeAccessKeychain))
    return true
  }
  public func installRequisite(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    let requisition = try cfg.parseRequisition.map(parseRequisition).get()
    let password = try resolveSecret(.init(cfg: cfg, secret: requisition.keychain.password))
    let requisites = requisites.isEmpty
      .else(requisites)
      .get(.init(requisition.requisites.keys))
    try prepareProvisions(cfg: cfg)
    try getProvisions(git: cfg.git, requisition: requisition, requisites: requisites)
      .forEach { try install(cfg: cfg, requisition: requisition, provision: $0) }
    try cleanKeychain(cfg: cfg, requisition: requisition, password: password)
    try requisites.forEach { requisite in try importKeychain(
      cfg: cfg,
      requisition: requisition,
      requisite: requisition.requisite(name: requisite)
    )}
    try Execute.checkStatus(reply: execute(requisition.allowXcodeAccessKeychain))
    return true
  }
  public func clearRequisites(cfg: Configuration) throws -> Bool {
    let requisition = try cfg.parseRequisition.map(parseRequisition).get()
    try prepareProvisions(cfg: cfg)
    try Execute.checkStatus(reply: execute(requisition.deleteKeychain))
    return true
  }
  public func reportExpiringRequisites(
    cfg: Configuration,
    days: UInt
  ) throws -> Bool {
    let requisition = try cfg.parseRequisition.map(parseRequisition).get()
    let now = getTime()
    let threshold = now.advanced(by: .init(days) * .day)
    var items: [Report.ExpiringRequisites.Item] = []
    let provisions = try getProvisions(
      git: cfg.git,
      requisition: requisition,
      requisites: .init(requisition.requisites.keys)
    )
    for file in provisions {
      let temp = try Id(cfg.systemTempFile)
        .map(execute)
        .map(Execute.parseText(reply:))
        .map(Files.Absolute.init(value:))
        .get()
      defer { try? Execute.checkStatus(reply: execute(cfg.systemDelete(path: temp))) }
      try Id(file)
        .map(cfg.git.cat(file:))
        .reduce(temp, cfg.systemWrite(file:execute:))
        .map(execute)
        .map(Execute.checkStatus(reply:))
        .get()
      let provision = try Id(temp)
        .map(requisition.decode(file:))
        .map(execute)
        .map(Execute.parseData(reply:))
        .reduce(Plist.Provision.self, plistDecoder.decode(_:from:))
        .get()
      guard provision.expirationDate < threshold else { continue }
      try items.append(.init(
        file: file.path.value,
        branch: file.ref.value.dropPrefix("refs/remotes/origin/"),
        name: provision.name,
        days: provision.expirationDate.timeIntervalSince(now) / .day
      ))
    }
    for requisite in requisition.requisites.values {
      let password = try resolveSecret(.init(cfg: cfg, secret: requisite.password))
      let certs = try Id(requisite.pkcs12)
        .reduce(.make(remote: requisition.branch), Git.File.init(ref:path:))
        .map(cfg.git.cat(file:))
        .reduce(password, requisition.parsePkcs12Certs(password:execute:))
        .map(execute)
        .map(Execute.parseLines(reply:))
        .get()
        .split(separator: .certStart)
        .mapEmpty([])
        .dropFirst()
        .compactMap { $0.split(separator: .certEnd).first }
        .map { ([.certStart] + $0 + [.certEnd])
          .map { $0 + "\n" }
          .joined()
          .utf8
        }
        .map(Data.init(_:))
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US")
      formatter.dateFormat = "MMM d HH:mm:ss yyyy zzz"
      for cert in certs {
        let lines = try Id(cert)
          .map(requisition.decodeCert(data:))
          .map(execute)
          .map(Execute.parseLines(reply:))
          .get()
          .map { $0.trimmingCharacters(in: .whitespaces) }
        let expirationDate = try lines
          .compactMap { try? $0.dropPrefix("notAfter=") }
          .first
          .flatMap(formatter.date(from:))
          .get { throw MayDay("openssl output") }
        guard expirationDate < threshold else { continue }
        let escaped = try lines
          .compactMap { try? $0.dropPrefix("commonName") }
          .first
          .get { throw MayDay("openssl output") }
          .trimmingCharacters(in: .newlines)
          .trimmingCharacters(in: .whitespaces)
          .dropPrefix("= ")
          .replacingOccurrences(of: "\\U", with: "\\u")
        let name = NSMutableString(string: escaped)
        CFStringTransform(name, nil, "Any-Hex/Java" as NSString, true)
        items.append(.init(
          file: requisite.pkcs12.value,
          branch: requisition.branch.name,
          name: .init(name),
          days: expirationDate.timeIntervalSince(now) / .day
        ))
      }
    }
    guard !items.isEmpty else { return true }
    cfg.reportExpiringRequisites(items: items)
    return true
  }
  func cleanKeychain(
    cfg: Configuration,
    requisition: Requisition,
    password: String
  ) throws {
    try Execute.checkStatus(reply: execute(requisition.deleteKeychain))
    try Execute.checkStatus(reply: execute(requisition.createKeychain(password: password)))
    try Execute.checkStatus(reply: execute(requisition.unlockKeychain(password: password)))
    try Execute.checkStatus(reply: execute(requisition.disableKeychainAutolock))
    let keychains = try Id(requisition.listVisibleKeychains)
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .map { $0.trimmingCharacters(in: .whitespaces.union(["\""])) }
    try Id(requisition.resetVisible(keychains: keychains + [requisition.keychain.name]))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  func importKeychain(
    cfg: Configuration,
    requisition: Requisition,
    requisite: Requisition.Requisite
  ) throws {
    let password = try resolveSecret(.init(cfg: cfg, secret: requisite.password))
    let temp = try Id(cfg.systemTempFile)
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Files.Absolute.init(value:))
      .get()
    defer { try? Execute.checkStatus(reply: execute(cfg.systemDelete(path: temp))) }
    try Id(requisite.pkcs12)
      .reduce(.make(remote: requisition.branch), Git.File.init(ref:path:))
      .map(cfg.git.cat(file:))
      .reduce(temp, cfg.write(file:execute:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try Id(requisition.importPkcs12(file: temp, password: password))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  func getProvisions(
    git: Git,
    requisition: Requisition,
    requisites: [String]
  ) throws -> [Git.File] {
    var files: Set<Files.Relative> = []
    let dirs = try requisites
      .map(requisition.requisite(name:))
      .flatMap(\.provisions)
    let ref = Git.Ref.make(remote: requisition.branch)
    for dir in dirs { try Id(dir)
      .reduce(ref, Git.Dir.init(ref:path:))
      .map(git.listTreeTrackedFiles(dir:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .map(Files.Relative.make(value:))
      .forEach { files.insert($0) }
    }
    return files.map({ Git.File.init(ref: ref, path: $0) })
  }
  func prepareProvisions(cfg: Configuration) throws {
    let provisions = try Id("~/Library/MobileDevice/Provisioning Profiles")
      .map(Files.ResolveAbsolute.make(path:))
      .map(resolveAbsolute)
    try provisions
      .map(cfg.systemDelete(path:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try provisions
      .map(cfg.createDir(path:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
  func install(cfg: Configuration, requisition: Requisition, provision: Git.File) throws {
    let temp = try Id(cfg.systemTempFile)
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Files.Absolute.init(value:))
      .get()
    defer { try? Execute.checkStatus(reply: execute(cfg.systemDelete(path: temp))) }
    try Id(provision)
      .map(cfg.git.cat(file:))
      .reduce(temp, cfg.systemWrite(file:execute:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    try Id(temp)
      .map(requisition.decode(file:))
      .map(execute)
      .map(Execute.parseData(reply:))
      .reduce(Plist.Provision.self, plistDecoder.decode(_:from:))
      .map(\.uuid)
      .map { "~/Library/MobileDevice/Provisioning Profiles/\($0).mobileprovision" }
      .map(Files.ResolveAbsolute.make(path:))
      .map(resolveAbsolute)
      .reduce(temp, cfg.systemMove(file:location:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
  }
}
extension TimeInterval {
  static var day: Self { 24 * 60 * 60 }
}
extension String {
  static var certStart: Self { "-----BEGIN CERTIFICATE-----" }
  static var certEnd: Self { "-----END CERTIFICATE-----" }
}
