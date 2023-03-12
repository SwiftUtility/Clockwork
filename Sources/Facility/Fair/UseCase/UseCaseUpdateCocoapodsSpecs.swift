import Foundation
import Facility
import FacilityPure
public extension UseCase {
  struct UpdateCocoapodsSpecs: Performer {
    public static func make() -> Self { .init() }
    public func perform(repo ctx: ContextRepo) throws -> Bool {
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
