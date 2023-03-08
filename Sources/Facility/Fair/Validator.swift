import Foundation
import Facility
import FacilityPure
extension ContextLocal {
  public func validateUnownedCode(stdout: Bool) throws -> Bool {
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
  public func validateFileTaboos(stdout: Bool) throws -> Bool {
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
  public func validateConflictMarkers(target: String, stdout: Bool) throws -> Bool {
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
public final class Validator {
  let execute: Try.Reply<Execute>
  let parseCodeOwnage: Try.Reply<ParseYamlFile<[String: Criteria]>>
  let parseFileTaboos: Try.Reply<ParseYamlFile<[FileTaboo]>>
  let listFileLines: Try.Reply<Files.ListFileLines>
  let logMessage: Act.Reply<LogMessage>
  let stdoutData: Act.Of<Data>.Go
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    parseCodeOwnage: @escaping Try.Reply<ParseYamlFile<[String: Criteria]>>,
    parseFileTaboos: @escaping Try.Reply<ParseYamlFile<[FileTaboo]>>,
    listFileLines: @escaping Try.Reply<Files.ListFileLines>,
    logMessage: @escaping Act.Reply<LogMessage>,
    stdoutData: @escaping Act.Of<Data>.Go,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.parseCodeOwnage = parseCodeOwnage
    self.parseFileTaboos = parseFileTaboos
    self.listFileLines = listFileLines
    self.logMessage = logMessage
    self.stdoutData = stdoutData
    self.jsonDecoder = jsonDecoder
  }
  public func validateUnownedCode(cfg: Configuration, json: Bool) throws -> Bool {
    guard try Execute.parseLines(reply: execute(cfg.git.changesList)).isEmpty
    else { throw Thrown("Git is dirty") }
    let approvals = try cfg.parseCodeOwnage(profile: cfg.profile)
      .map(parseCodeOwnage)
      .get { throw Thrown("No codeOwnage in profile") }
      .values
    var result: [String] = []
    for file in try Execute.parseLines(reply: execute(cfg.git.listAllTrackedFiles(ref: .head))) {
      guard approvals.contains(where: file.isMet(criteria:)).not else { continue }
      result.append(file)
    }
    if json { try stdoutData(JSONEncoder().encode(result)) }
    else { result.forEach { logMessage(.init(message: "Unowned file: \($0)")) } }
    return result.isEmpty
  }
  public func validateFileTaboos(cfg: Configuration, json: Bool) throws -> Bool {
    guard try Execute.parseLines(reply: execute(cfg.git.changesList)).isEmpty
    else { throw Thrown("Git is dirty") }
    let rules = try cfg.parseFileTaboos.map(parseFileTaboos).get()
    let nameRules = rules.filter(\.lines.isEmpty)
    let lineRules = rules.filter(\.lines.isEmpty.not)
    let files = try Execute.parseLines(reply: execute(cfg.git.listAllTrackedFiles(ref: .head)))
    var result: [Json.FileTaboo] = []
    for file in files { try autoreleasepool {
      for rule in nameRules where rule.files.isMet(file) {
        if rule.files.isMet(file) { result.append(.make(rule: rule.rule, file: file)) }
      }
      let lineRules = lineRules.filter { $0.files.isMet(file) }
      guard !lineRules.isEmpty else { return }
      let lines = try listFileLines(.init(file: .init(value: "\(cfg.git.root.value)/\(file)")))
      for (row, line) in lines.enumerated() {
        for rule in lineRules where rule.lines.isMet(line) {
          result.append(.make(rule: rule.rule, file: file, line: row + 1))
        }
      }
    }}
    if json { try stdoutData(JSONEncoder().encode(result)) }
    else { result.map(\.logMessage).forEach(logMessage) }
    return result.isEmpty
  }
  public func validateReviewConflictMarkers(
    cfg: Configuration,
    target: String,
    json: Bool
  ) throws -> Bool {
    guard try Execute.parseLines(reply: execute(cfg.git.changesList)).isEmpty
    else { throw Thrown("Git is dirty") }
    let fork = try Execute
      .parseLines(reply: execute(cfg.git.listCommits(
        in: [.head],
        notIn: [.make(remote: .make(name: target))],
        boundary: true
      )))
      .last
      .map(Git.Sha.make(value:))
      .get { throw Thrown("Fork point not found") }
    let initial = try Execute.parseText(reply: execute(cfg.git.getSha(ref: .head)))
    try Execute.checkStatus(reply: execute(cfg.git.resetSoft(ref: .make(sha: fork))))
    let result = try Execute.parseLines(reply: execute(cfg.git.listConflictMarkers))
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(
      ref: .make(sha: .make(value: initial))
    )))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    if json { try stdoutData(JSONEncoder().encode(result)) }
    else { result.map(LogMessage.init(message:)).forEach(logMessage) }
    return result.isEmpty
  }
  #warning("TBD implement default branch clockwork version check")
}
