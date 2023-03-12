import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct RequisitesImport: Performer {
    var pkcs12: Bool
    var provisions: Bool
    var requisites: [String]
    func perform(repo ctx: ContextLocal) throws -> Bool {
      let requisition = try ctx.parseRequisition()
      let requisites = try requisites.isEmpty.not
        .then(requisites)
        .get(.init(requisition.requisites.keys))
        .map(requisition.requisite(name:))
      if pkcs12 {
        let password = try ctx.parse(secret: requisition.keychain.password)
        try ctx.cleanKeychain(requisition: requisition, password: password)
        for requisite in requisites {
          try ctx.importKeychain(requisition: requisition, requisite: requisite)
        }
        try ctx.allowXcodeAccessKeychain(requisition: requisition, password: password)
      }
      if provisions {
        try ctx.deleteProvisions()
        for provision in try ctx.getProvisions(requisition: requisition, requisites: requisites) {
          try ctx.install(requisition: requisition, provision: provision)
        }
      }
      return true
    }
  }
}
