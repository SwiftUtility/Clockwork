import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ValidateUnownedCode: Performer {
    var stdout: Bool
    func perform(local ctx: ContextLocal) throws -> Bool {
      guard try ctx.gitIsClean() else { throw Thrown("Git is dirty") }
      guard let codeOwnage = try ctx.parseCodeOwnage()?.values
      else { throw Thrown("No codeOwnage in profile") }
      var result: [String] = []
      for file in try ctx.gitListAllTrackedFiles() {
        guard codeOwnage.contains(where: file.isMet(criteria:)).not else { continue }
        result.append(file)
        ctx.log(message: "Unowned file: \(file)")
      }
      if stdout { try ctx.sh.stdout(ctx.sh.rawEncoder.encode(result)) }
      return result.isEmpty
    }
  }
}
