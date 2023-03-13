import Foundation
import Facility
import FacilityPure
public extension Ctx.Sh {
  func get(env value: String) throws -> String {
    guard let result = env[value] else { throw Thrown("No env variable \(value)") }
    return result
  }
  func sysDelete(path: String) throws { try Id
    .make(Execute.make(.make(environment: env, arguments: ["rm", "-rf", path])))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func sysWrite(file: String, data: Data) throws { try Id
    .make(Execute.make(.make(environment: env, arguments:  ["tee", file])))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func sysCreateDir(path: String) throws { try Id
    .make(Execute.make(.make(environment: env, arguments: ["mkdir", "-p", path])))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func sysCreateTempFile() throws -> String { try Id
    .make(Execute.make(.make(environment: env, arguments: ["mktemp"])))
    .map(execute)
    .map(Execute.parseText(reply:))
    .get()
  }
  func sslDecodeCert(cert: Data) throws -> [String] { try Id
    .make(Execute.make(input: cert, .make(
      environment: env,
      arguments: ["openssl", "x509", "-enddate", "-subject", "-noout", "-nameopt", "multiline"]
    )))
    .map(execute)
    .map(Execute.parseLines(reply:))
    .get()
    .map({ $0.trimmingCharacters(in: .whitespaces) })
  }
  func sysMove(file: String, location: String) throws { try Id
    .make(Execute.make(.make(environment: env, arguments: ["mv", "-f", file, location])))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func sslListPkcs12Certs(
    password: String,
    data: Data
  ) throws -> [Data] { try Id
    .make(Execute.make(input: data, .make(
      environment: env,
      arguments: ["openssl", "pkcs12", "-passin", "pass:\(password)", "-passout", "pass:"]
    )))
    .map(execute)
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
  func securityAllowXcodeAccess(keychain: String, password: String) throws { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: [
        "security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:",
        "-s", "-k", password, keychain,
      ]
    )))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func securityImportPkcs12(
    keychain: String,
    file: String,
    password: String
  ) throws { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: [
        "security", "import", file, "-k", keychain,
        "-P", password, "-T", "/usr/bin/codesign", "-f", "pkcs12",
      ]
    )))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func securityListVisibleKeychains() throws -> [String] { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["security", "list-keychains", "-d", "user"]
    )))
    .map(execute)
    .map(Execute.parseLines(reply:))
    .get()
    .map { $0.trimmingCharacters(in: .whitespaces.union(["\""])) }
  }
  func securityResetVisible(keychains: [String]) throws { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["security", "list-keychains", "-d", "user", "-s"] + keychains
    )))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func securityDecode(file: String) throws -> Plist.Provision { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["security", "cms", "-D", "-i", file]
    )))
    .map(execute)
    .map(Execute.parseData(reply:))
    .reduce(Plist.Provision.self, plistDecoder.decode(_:from:))
    .get()
  }
  func securityDelete(keychain: String) throws { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["security", "delete-keychain", keychain]
    )))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func securityCreate(keychain: String, password: String) throws { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["security", "create-keychain", "-p", password, keychain]
    )))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func securityUnlock(keychain: String, password: String) throws { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["security", "unlock-keychain", "-p", password, keychain]
    )))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func securityDisableAutolock(keychain: String) throws { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["security", "set-keychain-settings", keychain]
    )))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func podAdd(name: String, url: String) throws { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["bundle", "exec", "pod", "repo", "add", name, url]
    )))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
  func podUpdate(name: String) throws { try Id
    .make(Execute.make(.make(
      environment: env,
      arguments: ["bundle", "exec", "pod", "repo", "update", name]
    )))
    .map(execute)
    .map(Execute.checkStatus(reply:))
    .get()
  }
}
