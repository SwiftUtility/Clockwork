import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct UpdateCocoapodsSpecs: Performer {
    func perform(repo ctx: ContextRepo) throws -> Bool {
      var cocoapods = try ctx.parseCocoapods()
      let specs = try ctx.sh.resolveAbsolute(.make(path: "~/.cocoapods/repos"))
      try ctx.deleteWrongSpecs(cocoapods: cocoapods, specs: specs)
      try ctx.installSpecs(cocoapods: cocoapods, specs: specs)
      try ctx.updateSpecs(cocoapods: &cocoapods, specs: specs)
      try ctx.sh.write(
        file: "\(ctx.git.root)/\(cocoapods.path)",
        data: .init(cocoapods.yaml.utf8)
      )
      return true
    }
  }
}
