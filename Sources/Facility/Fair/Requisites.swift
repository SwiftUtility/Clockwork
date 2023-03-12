import Foundation
import Facility
import FacilityPure
extension String {
  static var provisions: Self { "~/Library/MobileDevice/Provisioning Profiles" }
  static var certStart: Self { "-----BEGIN CERTIFICATE-----" }
  static var certEnd: Self { "-----END CERTIFICATE-----" }
}
extension TimeInterval {
  static var day: Self { 24 * 60 * 60 }
}
extension ContextLocal {
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
      try files.formUnion(gitListTreeTrackedFiles(dir: .make(ref: ref, path: dir)))
    }
    return files.map({ Ctx.Git.File.make(ref: ref, path: $0) })
  }
  func install(
    requisition: Requisition,
    provision: Ctx.Git.File
  ) throws {
    let temp = try sh.createTempFile()
    defer { try? sh.delete(path: temp) }
    let data = try gitCat(file: provision)
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
    let data = try gitCat(file: .make(ref: requisition.branch.remote, path: requisite.pkcs12))
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
