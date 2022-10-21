import Foundation
import Facility
import FacilityPure
public final class Validator {
  let execute: Try.Reply<Execute>
  let parseCodeOwnage: Try.Reply<Configuration.ParseYamlFile<[String: Yaml.Criteria]>>
  let resolveFileTaboos: Try.Reply<Configuration.ResolveFileTaboos>
  let listFileLines: Try.Reply<Files.ListFileLines>
  let logMessage: Act.Reply<LogMessage>
  let stdoutData: Act.Of<Data>.Go
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    parseCodeOwnage: @escaping Try.Reply<Configuration.ParseYamlFile<[String: Yaml.Criteria]>>,
    resolveFileTaboos: @escaping Try.Reply<Configuration.ResolveFileTaboos>,
    listFileLines: @escaping Try.Reply<Files.ListFileLines>,
    logMessage: @escaping Act.Reply<LogMessage>,
    stdoutData: @escaping Act.Of<Data>.Go,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.parseCodeOwnage = parseCodeOwnage
    self.resolveFileTaboos = resolveFileTaboos
    self.listFileLines = listFileLines
    self.logMessage = logMessage
    self.stdoutData = stdoutData
    self.jsonDecoder = jsonDecoder
  }
  public func validateUnownedCode(cfg: Configuration, json: Bool) throws -> Bool {
    guard try Execute.parseLines(reply: execute(cfg.git.changesList)).isEmpty
    else { throw Thrown("Git is dirty") }
    let approvals = try cfg.profile.codeOwnage
      .reduce(cfg.git, Configuration.ParseYamlFile<[String: Yaml.Criteria]>.init(git:file:))
      .map(parseCodeOwnage)
      .get { throw Thrown("No codeOwnage in profile") }
      .values
      .map(Criteria.init(yaml:))
    var result: [String] = []
    for file in try Execute.parseLines(reply: execute(cfg.git.listAllTrackedFiles(ref: .head))) {
      if approvals.contains(where: file.isMet(criteria:)) { result.append(file) }
    }
    if json { try stdoutData(JSONEncoder().encode(result)) }
    else { result.forEach { logMessage(.init(message: "Unowned file: \($0)")) } }
    return result.isEmpty
  }
  public func validateFileTaboos(cfg: Configuration, json: Bool) throws -> Bool {
    guard try Execute.parseLines(reply: execute(cfg.git.changesList)).isEmpty
    else { throw Thrown("Git is dirty") }
    let rules = try resolveFileTaboos(.init(cfg: cfg, profile: cfg.profile))
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
          result.append(.make(rule: rule.rule, file: file, line: row))
        }
      }
    }}
    if json { try stdoutData(JSONEncoder().encode(result)) }
    else { result.map(\.logMessage).forEach(logMessage) }
    return result.isEmpty
  }
  public func validateReviewConflictMarkers(
    cfg: Configuration,
    base: String,
    json: Bool
  ) throws -> Bool {
    guard try Execute.parseLines(reply: execute(cfg.git.changesList)).isEmpty
    else { throw Thrown("Git is dirty") }
    let initial = try Execute.parseText(reply: execute(cfg.git.getSha(ref: .head)))
    try Execute.checkStatus(reply: execute(cfg.git.resetSoft(ref: .make(sha: .make(value: base)))))
    let result = try Execute.parseLines(reply: execute(cfg.git.listConflictMarkers))
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(
      ref: .make(sha: .make(value: initial))
    )))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    if json { try stdoutData(JSONEncoder().encode(result)) }
    else { result.map(LogMessage.init(message:)).forEach(logMessage) }
    return result.isEmpty
  }
}
