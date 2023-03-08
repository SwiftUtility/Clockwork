import Foundation
import Facility
import FacilityPure
public extension ContextLocal {
  func validateUnownedCode(stdout: Bool) throws -> Bool {
    guard try repo.git.isClean(sh: sh) else { throw Thrown("Git is dirty") }
    guard let codeOwnage = try parseCodeOwnage()?.values
    else { throw Thrown("No codeOwnage in profile") }
    var result: [String] = []
    for file in try repo.git.listAllTrackedFiles(sh: sh) {
      guard codeOwnage.contains(where: file.isMet(criteria:)).not else { continue }
      result.append(file)
      log(message: "Unowned file: \(file)")
    }
    if stdout { try sh.stdout(sh.rawEncoder.encode(result)) }
    return result.isEmpty
  }
  func validateFileTaboos(stdout: Bool) throws -> Bool {
    guard try repo.git.isClean(sh: sh) else { throw Thrown("Git is dirty") }
    let rules = try parseFileTaboos()
    let nameRules = rules.filter(\.lines.isEmpty)
    let lineRules = rules.filter(\.lines.isEmpty.not)
    let files = try repo.git.listAllTrackedFiles(sh: sh)
    var result: [Json.FileTaboo] = []
    for file in files { try autoreleasepool {
      for rule in nameRules where rule.files.isMet(file) {
        result.append(.make(rule: rule.rule, file: file))
        log(message: "\(file): \(rule)")
      }
      let lineRules = lineRules.filter { $0.files.isMet(file) }
      guard !lineRules.isEmpty else { return }
      let lines = try sh.lineIterator(.make(value: "\(repo.git.root.value)/\(file)"))
      for (row, line) in lines.enumerated() {
        for rule in lineRules where rule.lines.isMet(line) {
          result.append(.make(rule: rule.rule, file: file, line: row + 1))
          log(message: "\(file):\(row + 1): \(rule)\n\(line)")
        }
      }
    }}
    if stdout { try sh.stdout(sh.rawEncoder.encode(result)) }
    return result.isEmpty
  }
  func validateConflictMarkers(target: String, stdout: Bool) throws -> Bool {
    guard try repo.git.isClean(sh: sh) else { throw Thrown("Git is dirty") }
    guard let fork = try repo.git.listCommits(
      sh: sh,
      in: [.head],
      notIn: [.make(remote: target)],
      boundary: true
    ).last else { throw Thrown("Fork point not found") }
    let initial = try repo.git.getSha(sh: sh, ref: .head).ref
    try repo.git.reset(sh: sh, ref: fork.ref, soft: true)
    let result = try repo.git.listConflictMarkers(sh: sh)
    try repo.git.reset(sh: sh, ref: initial, hard: true)
    try repo.git.clean(sh: sh)
    result.forEach(log(message:))
    if stdout { try sh.stdout(sh.rawEncoder.encode(result)) }
    return result.isEmpty
  }
}
