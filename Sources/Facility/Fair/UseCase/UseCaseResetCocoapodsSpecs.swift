import Foundation
import Facility
import FacilityPure
public extension UseCase {
  struct ResetCocoapodsSpecs: Performer {
    public static func make() -> Self { .init() }
    public func perform(repo ctx: ContextRepo) throws -> Bool {
      let cocoapods = try ctx.parseCocoapods()
      let specs = try ctx.sh.resolveAbsolute(.make(path: "~/.cocoapods/repos"))
      try ctx.deleteWrongSpecs(cocoapods: cocoapods, specs: specs)
      try ctx.installSpecs(cocoapods: cocoapods, specs: specs)
      try ctx.resetSpecs(cocoapods: cocoapods, specs: specs)
      return true
    }
  }
}
