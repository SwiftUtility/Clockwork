import Foundation
import Facility
import FacilityPure
public final class Validator {
  let execute: Try.Reply<Execute>
  let resolveCodeOwnage: Try.Reply<Configuration.ResolveCodeOwnage>
  let resolveFileTaboos: Try.Reply<Configuration.ResolveFileTaboos>
  let listFileLines: Try.Reply<Files.ListFileLines>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveCodeOwnage: @escaping Try.Reply<Configuration.ResolveCodeOwnage>,
    resolveFileTaboos: @escaping Try.Reply<Configuration.ResolveFileTaboos>,
    listFileLines: @escaping Try.Reply<Files.ListFileLines>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.resolveCodeOwnage = resolveCodeOwnage
    self.resolveFileTaboos = resolveFileTaboos
    self.listFileLines = listFileLines
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func validateUnownedCode(cfg: Configuration) throws -> Bool {
    guard try Execute.parseLines(reply: execute(cfg.git.notCommited)).isEmpty
    else { throw Thrown("Git is dirty") }
    let approvals = try resolveCodeOwnage(.init(cfg: cfg, profile: cfg.profile)).values
    var result = true
    for file in try Execute.parseLines(reply: execute(cfg.git.listAllTrackedFiles(ref: .head))) {
      guard !approvals.contains(where: file.isMet(criteria:)) else { continue }
      result = false
      logMessage(.init(message: "Unowned file: \(file)"))
    }
    return result
  }
  public func validateFileTaboos(cfg: Configuration) throws -> Bool {
    guard try Execute.parseLines(reply: execute(cfg.git.notCommited)).isEmpty
    else { throw Thrown("Git is dirty") }
    let rules = try resolveFileTaboos(.init(cfg: cfg, profile: cfg.profile))
    let nameRules = rules.filter(\.lines.isEmpty)
    let lineRules = rules.filter(\.lines.isEmpty.not)
    let files = try Execute.parseLines(reply: execute(cfg.git.listAllTrackedFiles(ref: .head)))
    var result = true
    for file in files { try autoreleasepool {
      for rule in nameRules {
        guard rule.files.isMet(file) else { continue }
        result = false
        logMessage(.init(message: "\(file): \(rule.rule)"))
      }
      let lineRules = lineRules.filter { $0.files.isMet(file) }
      guard !lineRules.isEmpty else { return }
      let lines = try listFileLines(.init(file: .init(value: "\(cfg.git.root.value)/\(file)")))
      for (row, line) in lines.enumerated() {
        for rule in lineRules {
          guard rule.lines.isMet(line) else { continue }
          result = false
          logMessage(.init(message: "\(file):\(row): \(rule.rule)"))
        }
      }
    }}
    return result
  }
  public func validateReviewConflictMarkers(cfg: Configuration, base: String) throws -> Bool {
    guard try Execute.parseLines(reply: execute(cfg.git.notCommited)).isEmpty
    else { throw Thrown("Git is dirty") }
    let initial = try Execute.parseText(reply: execute(cfg.git.getSha(ref: .head)))
    try Execute.checkStatus(reply: execute(cfg.git.resetSoft(ref: .make(sha: .init(value: base)))))
    let markers = try Execute.parseLines(reply: execute(cfg.git.listConflictMarkers))
    markers.forEach { logMessage(.init(message: $0)) }
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(
      ref: .make(sha: .init(value: initial))
    )))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    return markers.isEmpty
  }
}
