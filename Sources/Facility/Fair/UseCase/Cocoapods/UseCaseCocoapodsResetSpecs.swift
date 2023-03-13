import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct CocoapodsResetSpecs: Performer {
    func perform(repo ctx: ContextLocal) throws -> Bool {
      let cocoapods = try ctx.parseCocoapods()
      let specs = try ctx.sh.resolveAbsolute(.make(path: .cocoapods))
      try cocoapods.deleteWrongSpecs(ctx: ctx, path: specs)
      try cocoapods.installSpecs(ctx: ctx, path: specs)
      try cocoapods.resetSpecs(ctx: ctx, path: specs)
      return true
    }
  }
}
