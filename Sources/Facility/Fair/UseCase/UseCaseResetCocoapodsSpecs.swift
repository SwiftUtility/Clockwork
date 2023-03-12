import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ResetCocoapodsSpecs: Performer {
    func perform(repo ctx: ContextRepo) throws -> Bool {
      let cocoapods = try ctx.parseCocoapods()
      let specs = try ctx.sh.resolveAbsolute(.make(path: "~/.cocoapods/repos"))
      try ctx.deleteWrongSpecs(cocoapods: cocoapods, specs: specs)
      try ctx.installSpecs(cocoapods: cocoapods, specs: specs)
      try ctx.resetSpecs(cocoapods: cocoapods, specs: specs)
      return true
    }
  }
}
