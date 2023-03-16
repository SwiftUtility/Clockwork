import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ConnectExecuteContract: Performer {
    func perform(repo ctx: ContextLocal) throws -> Bool {
      let contract = try Contract.unpack(ctx: ctx)
      let ctx = try ctx.exclusive(contract: contract)
      #warning("TBD implement default branch clockwork version check")
      #warning("TBD implement contract version check")
      var performer = try contract.performer(ctx: ctx)
      try performer.perform(exclusive: ctx)

      #warning("TBD")
      return true
    }
  }
}
