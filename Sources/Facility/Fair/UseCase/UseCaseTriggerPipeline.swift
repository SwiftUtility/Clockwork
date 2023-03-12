import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct TriggerPipeline: ProtectedGitlabPerformer {
    var variables: [String]
    func perform(gitlab ctx: ContextGitlab, protected: Ctx.Gitlab.Protected) throws -> Bool {
      var variables: [Contract.Variable] = []
      for variable in self.variables {
        guard let index = variable.firstIndex(of: "=")
        else { throw Thrown("Wrong argument format \(variable)") }
        variables.append(.make(
          key: .init(variable[variable.startIndex..<index]),
          value: .init(variable[variable.index(after: index)..<variable.endIndex])
        ))
      }
      try ctx.triggerPipeline(ref: protected.project.defaultBranch, variables: variables)
      return true
    }
  }
}
