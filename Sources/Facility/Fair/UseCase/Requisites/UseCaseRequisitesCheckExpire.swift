import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct RequisitesCheckExpire: Performer {
    var days: UInt
    var stdout: Bool
    func perform(local ctx: ContextLocal) throws -> Bool {
      let requisition = try ctx.parseRequisition()
      let now = ctx.sh.getTime()
      let threshold = now.advanced(by: .init(days) * .day)
      var result: [Json.ExpiringRequisite] = []
      var provisions: Set<Ctx.Sys.Relative> = []
      let ref = requisition.branch.remote
      for dir in requisition.requisites.values.flatMap(\.provisions) {
        try provisions.formUnion(ctx.gitListTreeTrackedFiles(dir: .make(ref: ref, path: dir)))
      }
      for file in provisions {
        let temp = try ctx.sh.sysCreateTempFile()
        defer { try? ctx.sh.sysDelete(path: temp) }
        let data = try ctx.gitCat(file: .make(ref: ref, path: file))
        try ctx.sh.sysWrite(file: temp, data: data)
        let provision = try ctx.sh.securityDecode(file: temp)
        guard provision.expirationDate < threshold else { continue }
        let requisite = Json.ExpiringRequisite.make(
          file: file.value,
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
        for cert in try ctx.sh.sslListPkcs12Certs(password: password, data: pkcs12) {
          let lines = try ctx.sh.sslDecodeCert(cert: cert)
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
