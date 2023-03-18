import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct RequisitesImport: Performer {
    var pkcs12: Bool
    var provisions: Bool
    var requisites: [String]
    func perform(local ctx: ContextLocal) throws -> Bool {
      let requisition = try ctx.parseRequisition()
      let requisites = try requisites.isEmpty.not
        .then(requisites)
        .get(.init(requisition.requisites.keys))
        .map(requisition.requisite(name:))
      if pkcs12 {
        let password = try ctx.parse(secret: requisition.keychain.password)
        try ctx.sh.securityDelete(keychain: requisition.keychain.name)
        try ctx.sh.securityCreate(keychain: requisition.keychain.name, password: password)
        try ctx.sh.securityUnlock(keychain: requisition.keychain.name, password: password)
        try ctx.sh.securityDisableAutolock(keychain: requisition.keychain.name)
        let keychains = try ctx.sh.securityListVisibleKeychains()
        try ctx.sh.securityResetVisible(keychains: keychains + [requisition.keychain.name])
        for requisite in requisites {
          let password = try ctx.parse(secret: requisite.password)
          let temp = try ctx.sh.sysCreateTempFile()
          defer { try? ctx.sh.sysDelete(path: temp) }
          let data = try ctx.gitCat(file: .make(
            ref: requisition.branch.remote,
            path: requisite.pkcs12
          ))
          try ctx.sh.sysWrite(file: temp, data: data)
          try ctx.sh.securityImportPkcs12(
            keychain: requisition.keychain.name,
            file: temp,
            password: password
          )
        }
        try ctx.sh.securityAllowXcodeAccess(keychain: requisition.keychain.name, password: password)
      }
      if provisions {
        try ctx.sh.sysDelete(path: .provisions)
        try ctx.sh.sysCreateDir(path: .provisions)
        var provisions: Set<Ctx.Sys.Relative> = []
        let ref = requisition.branch.remote
        for dir in requisites.flatMap(\.provisions) {
          try provisions.formUnion(ctx.gitListTreeTrackedFiles(dir: .make(ref: ref, path: dir)))
        }
        for provision in provisions {
          let temp = try ctx.sh.sysCreateTempFile()
          defer { try? ctx.sh.sysDelete(path: temp) }
          let data = try ctx.gitCat(file: .make(ref: ref, path: provision))
          try ctx.sh.sysWrite(file: temp, data: data)
          let provision = try ctx.sh.securityDecode(file: temp)
          try ctx.sh.sysMove(
            file: temp,
            location: "\(String.provisions)/\(provision.uuid).mobileprovision"
          )
        }
      }
      return true
    }
  }
}
