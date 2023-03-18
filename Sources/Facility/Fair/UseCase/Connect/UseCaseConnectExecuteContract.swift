import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ConnectExecuteContract: Performer {
    func perform(local ctx: ContextLocal) throws -> Bool {
      let contract = try Contract.unpack(ctx: ctx)
      let ctx = try ctx.exclusive(parent: contract.job)
      #warning("TBD implement default branch clockwork version check")
      #warning("TBD implement contract version check")
      var performer = try contract.performer(ctx: ctx)
      try performer.perform(exclusive: ctx)

      #warning("TBD")
      return true
    }
  }
}
