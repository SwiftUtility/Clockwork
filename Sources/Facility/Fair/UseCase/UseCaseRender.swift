import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct Render: Performer {
    var template: String
    var stdin: AnyCodable?
    var args: [String]
    func perform(repo ctx: FacilityPure.ContextLocal) throws -> Bool {
      try Id
        .make(.make(
          template: template,
          stdin: stdin,
          args: args,
          env: ctx.sh.env
        ))
        .map(ctx.generate)
        .map(\.utf8)
        .map(Data.init(_:))
        .map(ctx.sh.stdout)
        .get()
      return true
    }
  }
}