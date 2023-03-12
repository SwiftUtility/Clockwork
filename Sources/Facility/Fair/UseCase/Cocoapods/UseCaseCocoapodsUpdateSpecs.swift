import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct CocoapodsUpdateSpecs: Performer {
    func perform(repo ctx: ContextLocal) throws -> Bool {
      var cocoapods = try ctx.parseCocoapods()
      let specs = try ctx.sh.resolveAbsolute(.make(path: "~/.cocoapods/repos"))
      try cocoapods.deleteWrongSpecs(ctx: ctx, path: specs)
      try cocoapods.installSpecs(ctx: ctx, path: specs)
      try cocoapods.updateSpecs(ctx: ctx, path: specs)
      try ctx.sh.write(
        file: "\(ctx.git.root)/\(cocoapods.path)",
        data: .init(cocoapods.yaml.utf8)
      )
      return true
    }
  }
}
