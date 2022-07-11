import Foundation
import Facility
import FacilityPure
public final class Validator {
  let execute: Try.Reply<Execute>
  let resolveCodeOwnage: Try.Reply<Configuration.ResolveCodeOwnage>
  let resolveFileTaboos: Try.Reply<Configuration.ResolveFileTaboos>
  let resolveForbiddenCommits: Try.Reply<Configuration.ResolveForbiddenCommits>
  let listFileLines: Try.Reply<Files.ListFileLines>
  let report: Act.Reply<Report>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveCodeOwnage: @escaping Try.Reply<Configuration.ResolveCodeOwnage>,
    resolveFileTaboos: @escaping Try.Reply<Configuration.ResolveFileTaboos>,
    resolveForbiddenCommits: @escaping Try.Reply<Configuration.ResolveForbiddenCommits>,
    listFileLines: @escaping Try.Reply<Files.ListFileLines>,
    report: @escaping Act.Reply<Report>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.resolveCodeOwnage = resolveCodeOwnage
    self.resolveFileTaboos = resolveFileTaboos
    self.resolveForbiddenCommits = resolveForbiddenCommits
    self.listFileLines = listFileLines
    self.report = report
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func validateUnownedCode(cfg: Configuration) throws -> Bool {
    let approvals = try Id(cfg.profile)
      .reduce(cfg, Configuration.ResolveCodeOwnage.init(cfg:profile:))
      .map(resolveCodeOwnage)
      .get()
    let files = try Id
      .make(cfg.git)
      .reduce(curry: .head, Git.listAllTrackedFiles(ref:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .filter { file in !approvals.contains { $0.value.isMet(file) } }
    guard !files.isEmpty else { return true }
    files
      .map { $0 + ": unowned" }
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    report(cfg.reportUnownedCode(files: files))
    return false
  }
  public func validateFileTaboos(cfg: Configuration) throws -> Bool {
    let rules = try resolveFileTaboos(.init(cfg: cfg, profile: cfg.profile))
    guard try Execute.parseLines(reply: execute(cfg.git.notCommited)).isEmpty
    else { throw Thrown("Git is dirty") }
    let nameRules = rules.filter { $0.lines.isEmpty }
    let lineRules = rules.filter { !$0.lines.isEmpty }
    let files = try Id
      .make(Git.Ref.head)
      .map(cfg.git.listAllTrackedFiles(ref:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
    var issues: [FileTaboo.Issue] = []
    for file in files { try autoreleasepool {
      nameRules
        .filter { $0.files.isMet(file) }
        .map { FileTaboo.Issue(rule: $0.rule, file: file) }
        .forEach { issue in
          logMessage(.init(message: issue.logMessage))
          issues.append(issue)
        }
      let lineRules = lineRules
        .filter { $0.files.isMet(file) }
      if lineRules.isEmpty { return }
      try Id("\(cfg.git.root.value)/\(file)")
        .map(Files.Absolute.init(value:))
        .map(Files.ListFileLines.init(file:))
        .map(listFileLines)
        .get()
        .enumerated()
        .flatMap { row, line in lineRules
          .filter { $0.lines.isMet(line) }
          .map { FileTaboo.Issue(rule: $0.rule, file: file, line: row) }
        }
        .forEach { issue in
          logMessage(.init(message: issue.logMessage))
          issues.append(issue)
        }
    }}
    guard !issues.isEmpty else { return true }
    report(cfg.reportFileTaboos(issues: issues))
    return false
  }
  public func validateReviewObsolete(cfg: Configuration, target: String) throws -> Bool {
    let obsolescence = try cfg.profile.obsolescence.get()
    let files = try Id(target)
      .map(Git.Branch.init(name:))
      .map(Git.Ref.make(remote:))
      .reduce(.head, cfg.git.listChangedOutsideFiles(source:target:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .filter(obsolescence.isMet(_:))
    guard !files.isEmpty else { return true }
    report(cfg.reportReviewObsolete(files: files))
    return false
  }
  public func validateForbiddenCommits(cfg: Configuration) throws -> Bool {
    let commits = try resolveForbiddenCommits(.init(cfg: cfg)).compactMap { sha in try Id
      .make(.make(sha: sha))
      .reduce(.head, cfg.git.check(child:parent:))
      .map(execute)
      .map(Execute.parseSuccess(reply:))
      .get()
      .then(sha.value)
    }
    guard !commits.isEmpty else { return true }
    report(cfg.reportForbiddenCommits(commits: commits))
    return false
  }
  public func validateReviewConflictMarkers(cfg: Configuration, target: String) throws -> Bool {
    let initial = try Id(.head)
      .map(cfg.git.getSha(ref:))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    try Id
      .make(cfg.git.mergeBase(.head, .make(remote: .init(name: target))))
      .map(execute)
      .map(Execute.parseText(reply:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .map(cfg.git.resetSoft(ref:))
      .map(execute)
      .map(Execute.checkStatus(reply:))
      .get()
    let markers = try Id(cfg.git.listConflictMarkers)
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
    try Execute.checkStatus(reply: execute(cfg.git.resetHard(ref: initial)))
    try Execute.checkStatus(reply: execute(cfg.git.clean))
    guard !markers.isEmpty else { return true }
    markers
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    report(cfg.reportConflictMarkers(markers: markers))
    return false
  }
}
