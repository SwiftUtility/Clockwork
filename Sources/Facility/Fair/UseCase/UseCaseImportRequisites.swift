import Foundation
import Facility
import FacilityPure
public extension UseCase {
  struct ImportRequisites: Performer {
    var pkcs12: Bool
    var provisions: Bool
    var requisites: [String]
    public static func make(
      pkcs12: Bool,
      provisions: Bool,
      requisites: [String]
    ) -> Self { .init(
      pkcs12: pkcs12,
      provisions: provisions,
      requisites: requisites
    )}
    public func perform(repo ctx: ContextRepo) throws -> Bool {
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
