import Foundation
import Facility
import FacilityPure
public extension ContextLocal {
  func requisitesImport(provisions requisites: [String]) throws -> Bool {
    let requisition = try parseRequisition()
    let requisites = try requisites.isEmpty.not
      .then(requisites)
      .get(.init(requisition.requisites.keys))
      .map(requisition.requisite(name:))
    try deleteProvisions()
    try getProvisions(requisition: requisition, requisites: requisites).forEach({ try install(
      requisition: requisition, provision: $0
    )})
    return true
  }
  func requisitesImport(pkcs12 requisites: [String]) throws -> Bool {
    let requisition = try parseRequisition()
    let password = try parse(secret: requisition.keychain.password)
    let requisites = try requisites.isEmpty.not
      .then(requisites)
      .get(.init(requisition.requisites.keys))
      .map(requisition.requisite(name:))
    try cleanKeychain(requisition: requisition, password: password)
    for requisite in requisites {
      try importKeychain(requisition: requisition, requisite: requisite)
    }
    try allowXcodeAccessKeychain(requisition: requisition, password: password)
    return true
  }
  func requisitesImport(requisites: [String]) throws -> Bool {
    let requisition = try parseRequisition()
    let password = try parse(secret: requisition.keychain.password)
    let requisites = try requisites.isEmpty.not
      .then(requisites)
      .get(.init(requisition.requisites.keys))
      .map(requisition.requisite(name:))
    try deleteProvisions()
    try getProvisions(requisition: requisition, requisites: requisites).forEach({ try install(
      requisition: requisition, provision: $0
    )})
    try cleanKeychain(requisition: requisition, password: password)
    for requisite in requisites {
      try importKeychain(requisition: requisition, requisite: requisite)
    }
    try allowXcodeAccessKeychain(requisition: requisition, password: password)
    return true
  }
  func requisitesClear() throws -> Bool {
    let requisition = try parseRequisition()
    try deleteProvisions()
    try deleteKeychain(requisition: requisition)
    return true
  }
  func requisitesCheckExpire(days: UInt, stdout: Bool) throws -> Bool {
    let requisition = try parseRequisition()
    let now = sh.getTime()
    let threshold = now.advanced(by: .init(days) * .day)
    var result: [Json.ExpiringRequisite] = []
    let provisions = try getProvisions(
      requisition: requisition,
      requisites: .init(requisition.requisites.values)
    )
    for file in provisions {
      let temp = try sh.createTempFile()
      defer { try? sh.delete(path: temp) }
      let data = try repo.git.cat(sh: sh, file: file)
      try sh.write(file: temp, data: data)
      let provision = try securityDecode(file: temp)
      guard provision.expirationDate < threshold else { continue }
      let requisite = Json.ExpiringRequisite.make(
        file: file.path.value,
        branch: requisition.branch.name,
        name: provision.name,
        days: provision.expirationDate.timeIntervalSince(now) / .day
      )
      result.append(requisite)
      log(message: requisite.logMessage)
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "MMM d HH:mm:ss yyyy zzz"
    for requisite in requisition.requisites.values {
      let password = try parse(secret: requisite.password)
      let pkcs12 = try repo.git.cat(sh: sh, file: .make(
        ref: requisition.branch.remote,
        path: requisite.pkcs12
      ))
      for cert in try parsePkcs12Certs(requisition: requisition, password: password, data: pkcs12) {
        let lines = try decodeCert(cert: cert)
        guard let expirationDate = lines
          .compactMap({ try? $0.dropPrefix("notAfter=") })
          .first
          .flatMap(formatter.date(from:))
        else { throw MayDay("Unexpected openssl output") }
        guard expirationDate < threshold else { continue }
        guard let escaped = try lines
          .compactMap({ try? $0.dropPrefix("commonName") })
          .first?
          .trimmingCharacters(in: .newlines)
          .trimmingCharacters(in: .whitespaces)
          .dropPrefix("= ")
          .replacingOccurrences(of: "\\U", with: "\\u")
        else { throw MayDay("Unexpected openssl output") }
        let name = NSMutableString(string: escaped)
        CFStringTransform(name, nil, "Any-Hex/Java" as NSString, true)
        let requisite = Json.ExpiringRequisite.make(
          file: requisite.pkcs12.value,
          branch: requisition.branch.name,
          name: .init(name),
          days: expirationDate.timeIntervalSince(now) / .day
        )
        result.append(requisite)
        log(message: requisite.logMessage)
      }
    }
    if stdout { try sh.stdout(sh.rawEncoder.encode(result)) }
    return result.isEmpty.not
  }
}
private extension String {
  static var provisions: Self { "~/Library/MobileDevice/Provisioning Profiles" }
  static var certStart: Self { "-----BEGIN CERTIFICATE-----" }
  static var certEnd: Self { "-----END CERTIFICATE-----" }
}
private extension TimeInterval {
  static var day: Self { 24 * 60 * 60 }
}
private extension ContextLocal {
  func deleteProvisions() throws {
    try sh.delete(path: .provisions)
    try sh.createDir(path: .provisions)
  }
  func getProvisions(
    requisition: Requisition,
    requisites: [Requisition.Requisite]
  ) throws -> [Ctx.Git.File] {
    var files: Set<Ctx.Sys.Relative> = []
    let dirs = requisites.flatMap(\.provisions)
    let ref = requisition.branch.remote
    for dir in dirs {
      try files.formUnion(repo.git.listTreeTrackedFiles(sh: sh, dir: .make(ref: ref, path: dir)))
    }
    return files.map({ Ctx.Git.File.make(ref: ref, path: $0) })
  }
  func install(
    requisition: Requisition,
    provision: Ctx.Git.File
  ) throws {
    let temp = try sh.createTempFile()
    defer { try? sh.delete(path: temp) }
    let data = try repo.git.cat(sh: sh, file: provision)
    try sh.write(file: temp, data: data)
    let provision = try securityDecode(file: temp)
    try move(file: temp, location: "\(String.provisions)/\(provision.uuid).mobileprovision")
  }
  func cleanKeychain(requisition: Requisition, password: String) throws {
    try deleteKeychain(requisition: requisition)
    try createKeychain(requisition: requisition, password: password)
    try unlockKeychain(requisition: requisition, password: password)
    try disableKeychainAutolock(requisition: requisition)
    let keychains = try listVisibleKeychains(requisition: requisition)
    try resetVisible(requisition: requisition, keychains: keychains)
  }
  func importKeychain(
    requisition: Requisition,
    requisite: Requisition.Requisite
  ) throws {
    let password = try parse(secret: requisite.password)
    let temp = try sh.createTempFile()
    defer { try? sh.delete(path: temp) }
    let data = try repo.git.cat(sh: sh, file: .make(
      ref: requisition.branch.remote,
      path: requisite.pkcs12
    ))
    try sh.write(file: temp, data: data)
    try importPkcs12(requisition: requisition, file: temp, password: password)
  }
  func securityDecode(file: String) throws -> Plist.Provision { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["security", "cms", "-D", "-i", file]
    )))
    .map(sh.execute)
    .map(Execute.parseData(reply:))
    .reduce(Plist.Provision.self, sh.plistDecoder.decode(_:from:))
    .get()
  }
  func deleteKeychain(requisition: Requisition) throws { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["security", "delete-keychain", requisition.keychain.name]
    )))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func createKeychain(requisition: Requisition, password: String) throws { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["security", "create-keychain", "-p", password, requisition.keychain.name]
    )))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func unlockKeychain(requisition: Requisition, password: String) throws { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["security", "unlock-keychain", "-p", password, requisition.keychain.name]
    )))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func disableKeychainAutolock(requisition: Requisition) throws { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["security", "set-keychain-settings", requisition.keychain.name]
    )))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func listVisibleKeychains(requisition: Requisition) throws -> [String] { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["security", "list-keychains", "-d", "user"]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
    .map { $0.trimmingCharacters(in: .whitespaces.union(["\""])) }
  }
  func resetVisible(requisition: Requisition, keychains: [String]) throws { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: ["security", "list-keychains", "-d", "user", "-s"] + keychains
    )))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func importPkcs12(
    requisition: Requisition,
    file: String,
    password: String
  ) throws { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: [
        "security", "import", file, "-k", requisition.keychain.name,
        "-P", password, "-T", "/usr/bin/codesign", "-f", "pkcs12",
      ]
    )))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func allowXcodeAccessKeychain(requisition: Requisition, password: String) throws { try Id
    .make(Execute.make(.make(
      environment: sh.env,
      arguments: [
        "security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
        "-s", "-k", password, requisition.keychain.name,
      ]
    )))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func parsePkcs12Certs(
    requisition: Requisition,
    password: String,
    data: Data
  ) throws -> [Data] { try Id
    .make(Execute.make(input: data, .make(
      environment: sh.env,
      arguments: ["openssl", "pkcs12", "-passin", "pass:\(password)", "-passout", "pass:"]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
    .split(separator: .certStart)
    .mapEmpty([])
    .dropFirst()
    .compactMap({ $0.split(separator: .certEnd).first })
    .map({ somes in  ([.certStart] + somes + [.certEnd]).map({ $0 + "\n" }).joined() })
    .map(\.utf8)
    .map(Data.init(_:))
  }
  func decodeCert(cert: Data) throws -> [String] { try Id
    .make(Execute.make(input: cert, .make(
      environment: sh.env,
      arguments: ["openssl", "x509", "-enddate", "-subject", "-noout", "-nameopt", "multiline"]
    )))
    .map(sh.execute)
    .map(Execute.parseLines(reply:))
    .get()
    .map({ $0.trimmingCharacters(in: .whitespaces) })
  }
  func move(file: String, location: String) throws { try Id
    .make(Execute.make(.make(environment: sh.env, arguments: ["mv", "-f", file, location])))
    .map(sh.execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
}
