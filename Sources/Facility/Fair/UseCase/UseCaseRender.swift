import Foundation
import Facility
import FacilityPure
extension UseCase {
  public struct Render: Performer {
    var template: String
    var stdin: AnyCodable?
    var args: [String]
    public func perform(repo ctx: FacilityPure.ContextRepo) throws -> Bool {
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
    public static func make(template: String, stdin: AnyCodable?, args: [String]) -> Self {
      .init(template: template, stdin: stdin, args: args)
    }
  }
}
