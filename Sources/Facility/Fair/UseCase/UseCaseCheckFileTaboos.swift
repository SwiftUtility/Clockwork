import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct CheckFileTaboos: Performer {
    var stdout: Bool
    func perform(repo ctx: ContextRepo) throws -> Bool {
      guard try ctx.gitIsClean() else { throw Thrown("Git is dirty") }
      let rules = try ctx.parseFileTaboos()
      let nameRules = rules.filter(\.lines.isEmpty)
      let lineRules = rules.filter(\.lines.isEmpty.not)
      let files = try ctx.gitListAllTrackedFiles()
      var result: [Json.FileTaboo] = []
      for file in files { try autoreleasepool {
        for rule in nameRules where rule.files.isMet(file) {
          result.append(.make(rule: rule.rule, file: file))
          ctx.log(message: "\(file): \(rule)")
        }
        let lineRules = lineRules.filter { $0.files.isMet(file) }
        guard !lineRules.isEmpty else { return }
        let lines = try ctx.sh.lineIterator(.make(value: "\(ctx.git.root.value)/\(file)"))
        for (row, line) in lines.enumerated() {
          for rule in lineRules where rule.lines.isMet(line) {
            result.append(.make(rule: rule.rule, file: file, line: row + 1))
            ctx.log(message: "\(file):\(row + 1): \(rule)\n\(line)")
          }
        }
      }}
      if stdout { try ctx.sh.stdout(ctx.sh.rawEncoder.encode(result)) }
      return result.isEmpty
    }
  }
}
