import Foundation
import Facility
import FacilityPure
public final class Requisitor {
  let execute: Try.Reply<Execute>
  let report: Act.Reply<Report>
  let resolveAbsolute: Try.Reply<Files.ResolveAbsolute>
  let resolveRequisition: Try.Reply<Configuration.ResolveRequisition>
  let resolveSecret: Try.Reply<Configuration.ResolveSecret>
  let resolveCocoapods: Try.Reply<Configuration.ResolveCocoapods>
  let persistCocoapods: Try.Reply<Configuration.PersistCocoapods>
  let listFileSystem: Try.Reply<Files.ListFileSystem>
  let getTime: Act.Do<Date>
  let plistDecoder: PropertyListDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    report: @escaping Act.Reply<Report>,
    resolveAbsolute: @escaping Try.Reply<Files.ResolveAbsolute>,
    resolveRequisition: @escaping Try.Reply<Configuration.ResolveRequisition>,
    resolveSecret: @escaping Try.Reply<Configuration.ResolveSecret>,
    resolveCocoapods: @escaping Try.Reply<Configuration.ResolveCocoapods>,
    persistCocoapods: @escaping Try.Reply<Configuration.PersistCocoapods>,
    listFileSystem: @escaping Try.Reply<Files.ListFileSystem>,
    getTime: @escaping Act.Do<Date>,
    plistDecoder: PropertyListDecoder
  ) {
    self.execute = execute
    self.report = report
    self.resolveAbsolute = resolveAbsolute
    self.resolveRequisition = resolveRequisition
    self.resolveSecret = resolveSecret
    self.resolveCocoapods = resolveCocoapods
    self.persistCocoapods = persistCocoapods
    self.listFileSystem = listFileSystem
    self.getTime = getTime
    self.plistDecoder = plistDecoder
  }
  public func installProvisions(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    let requisition = try resolveRequisition(.init(cfg: cfg))
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
    let requisition = try resolveRequisition(.init(cfg: cfg))
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
    let requisition = try resolveRequisition(.init(cfg: cfg))
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
    let requisition = try resolveRequisition(.init(cfg: cfg))
    try prepareProvisions(cfg: cfg)
    try Execute.checkStatus(reply: execute(requisition.deleteKeychain))
    return true
  }
  public func reportExpiringRequisites(
    cfg: Configuration,
    days: UInt
  ) throws -> Bool {
    let requisition = try resolveRequisition(.init(cfg: cfg))
    let threshold = getTime().advanced(by: .init(days) * .day)
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
      let days = min(0, Int(threshold.timeIntervalSince(provision.expirationDate) / .day))
      items.append(.init(file: file.path.value, name: provision.name, days: "\(days)"))
    }
    for requisite in requisition.requisites.values {
      let password = try resolveSecret(.init(cfg: cfg, secret: requisite.password))
      let certs = try Id(requisite.pkcs12)
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
        let date = try lines
          .compactMap { try? $0.dropPrefix("notAfter=") }
          .first
          .flatMap(formatter.date(from:))
          .get { throw MayDay("openssl output") }
        guard date < threshold else { continue }
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
        let days = min(0, Int(threshold.timeIntervalSince(date) / .day))
        items.append(.init(
          file: requisite.pkcs12.path.value,
          name: .init(name),
          days: "\(days)")
        )
      }
    }
    guard !items.isEmpty else { return true }
    report(cfg.reportExpiringRequisites(items: items))
    return true
  }
  public func restoreCocoapodsSpecs(
    cfg: Configuration
  ) throws -> Bool {
    let cocoapods = try resolveCocoapods(.init(cfg: cfg, profile: cfg.profile))
    let specs = try resolveAbsolute(.make(path: "~/.cocoapods/repos"))
    try deleteWrongSpecs(cfg: cfg, cocoapods: cocoapods, specs: specs)
    try installSpecs(cfg: cfg, cocoapods: cocoapods, specs: specs)
    try resetSpecs(cfg: cfg, cocoapods: cocoapods, specs: specs)
    return true
  }
  public func updateCocoapodsSpecs(
    cfg: Configuration
  ) throws -> Bool {
    var cocoapods = try resolveCocoapods(.init(cfg: cfg, profile: cfg.profile))
    let specs = try resolveAbsolute(.make(path: "~/.cocoapods/repos"))
    try deleteWrongSpecs(cfg: cfg, cocoapods: cocoapods, specs: specs)
    try installSpecs(cfg: cfg, cocoapods: cocoapods, specs: specs)
    cocoapods = try updateSpecs(cfg: cfg, cocoapods: cocoapods, specs: specs)
    try persistCocoapods(.init(cfg: cfg, cocoapods: cocoapods))
    return true
  }
  func deleteWrongSpecs(
    cfg: Configuration,
    cocoapods: Cocoapods,
    specs: Files.Absolute
  ) throws {
    guard let names = try? listFileSystem(.init(include: .directories, path: specs)) else { return }
    for name in names {
      let path = try resolveAbsolute(specs.makeResolve(path: name))
      let git = try Git(verbose: cfg.verbose, env: cfg.env, root: path)
      guard let url = try? Execute.parseText(reply: execute(git.getOriginUrl)) else { continue }
      for spec in cocoapods.specs {
        guard spec.url == url else { continue }
        if spec.name != name {
          try Execute.checkStatus(reply: execute(cfg.systemDelete(path: path)))
        }
      }
    }
  }
  func installSpecs(
    cfg: Configuration,
    cocoapods: Cocoapods,
    specs: Files.Absolute
  ) throws {
    for spec in cocoapods.specs {
      let path = try resolveAbsolute(specs.makeResolve(path: spec.name))
      let git = try Git(verbose: cfg.verbose, env: cfg.env, root: path)
      guard case nil = try? Execute.parseText(reply: execute(git.getSha(ref: .head)))
      else { continue }
      try Execute.checkStatus(reply: execute(cfg.podAddSpec(name: spec.name, url: spec.url)))
    }
  }
  func resetSpecs(
    cfg: Configuration,
    cocoapods: Cocoapods,
    specs: Files.Absolute
  ) throws {
    for spec in cocoapods.specs {
      let path = try resolveAbsolute(specs.makeResolve(path: spec.name))
      let git = try Git(verbose: cfg.verbose, env: cfg.env, root: path)
      let sha = try Git.Sha(value: Execute.parseText(reply: execute(git.getSha(ref: .head))))
      guard sha != spec.sha else { continue }
      try Execute.checkStatus(reply: execute(cfg.podUpdateSpec(name: spec.name)))
      try Execute.checkStatus(reply: execute(git.resetHard(ref: .make(sha: spec.sha))))
      try Execute.checkStatus(reply: execute(git.clean))
    }
  }
  func updateSpecs(
    cfg: Configuration,
    cocoapods: Cocoapods,
    specs: Files.Absolute
  ) throws -> Cocoapods {
    var result = Cocoapods.empty
    for var spec in cocoapods.specs {
      try Execute.checkStatus(reply: execute(cfg.podUpdateSpec(name: spec.name)))
      let path = try resolveAbsolute(specs.makeResolve(path: spec.name))
      let git = try Git(verbose: cfg.verbose, env: cfg.env, root: path)
      spec.sha = try .init(value: Execute.parseText(reply: execute(git.getSha(ref: .head))))
      result.specs.append(spec)
    }
    return result
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
  ) throws -> Set<Git.File> {
    var result: Set<Git.File> = []
    let dirs = try requisites
      .map(requisition.requisite(name:))
      .flatMap(\.provisions)
    for dir in dirs { try Id(dir)
      .map(git.listTreeTrackedFiles(dir:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .map(Files.Relative.init(value:))
      .forEach { result.insert(.init(ref: dir.ref, path: $0)) }
    }
    return result
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
