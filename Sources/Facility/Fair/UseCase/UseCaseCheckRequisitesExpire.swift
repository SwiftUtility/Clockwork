import Foundation
import Facility
import FacilityPure
public extension UseCase {
  struct CheckRequisitesExpire: Performer {
    public var days: UInt
    public var stdout: Bool
    public static func make(
      days: UInt,
      stdout: Bool
    ) -> Self { .init(
      days: days,
      stdout: stdout
    )}
    public func perform(repo ctx: ContextRepo) throws -> Bool {
      let requisition = try ctx.parseRequisition()
      let now = ctx.sh.getTime()
      let threshold = now.advanced(by: .init(days) * .day)
      var result: [Json.ExpiringRequisite] = []
      let provisions = try ctx.getProvisions(
        requisition: requisition,
        requisites: .init(requisition.requisites.values)
      )
      for file in provisions {
        let temp = try ctx.sh.createTempFile()
        defer { try? ctx.sh.delete(path: temp) }
        let data = try ctx.gitCat(file: file)
        try ctx.sh.write(file: temp, data: data)
        let provision = try ctx.securityDecode(file: temp)
        guard provision.expirationDate < threshold else { continue }
        let requisite = Json.ExpiringRequisite.make(
          file: file.path.value,
          branch: requisition.branch.name,
          name: provision.name,
          days: provision.expirationDate.timeIntervalSince(now) / .day
        )
        result.append(requisite)
        ctx.log(message: requisite.logMessage)
      }
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "en_US")
      formatter.dateFormat = "MMM d HH:mm:ss yyyy zzz"
      for requisite in requisition.requisites.values {
        let password = try ctx.parse(secret: requisite.password)
        let pkcs12 = try ctx.gitCat(file: .make(
          ref: requisition.branch.remote,
          path: requisite.pkcs12
        ))
        for cert in try ctx.parsePkcs12Certs(
          requisition: requisition,
          password: password,
          data: pkcs12
        ) {
          let lines = try ctx.decodeCert(cert: cert)
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
          ctx.log(message: requisite.logMessage)
        }
      }
      if stdout { try ctx.sh.stdout(ctx.sh.rawEncoder.encode(result)) }
      return result.isEmpty.not
    }
  }
}
