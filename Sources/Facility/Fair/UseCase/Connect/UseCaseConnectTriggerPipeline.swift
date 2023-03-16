import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ConnectTriggerPipeline: ProtectedGitlabPerformer {
    var variables: [String]
    func perform(protected ctx: ContextGitlabProtected) throws -> Bool {
      var variables: [Contract.Variable] = []
      for variable in self.variables {
        guard let index = variable.firstIndex(of: "=")
        else { throw Thrown("Wrong argument format \(variable)") }
        variables.append(.make(
          key: .init(variable[variable.startIndex..<index]),
          value: .init(variable[variable.index(after: index)..<variable.endIndex])
        ))
      }
      try ctx.triggerPipeline(ref: ctx.project.defaultBranch, variables: variables)
      return true
    }
  }
}
