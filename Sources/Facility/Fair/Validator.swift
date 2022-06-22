import Foundation
import Facility
import FacilityPure
public final class Validator {
  let execute: Try.Reply<Execute>
  let resolveCodeOwnage: Try.Reply<Configuration.ResolveCodeOwnage>
  let resolveFileTaboos: Try.Reply<Configuration.ResolveFileTaboos>
  let resolveForbiddenCommits: Try.Reply<Configuration.ResolveForbiddenCommits>
  let listFileLines: Try.Reply<Files.ListFileLines>
  let report: Try.Reply<Report>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveCodeOwnage: @escaping Try.Reply<Configuration.ResolveCodeOwnage>,
    resolveFileTaboos: @escaping Try.Reply<Configuration.ResolveFileTaboos>,
    resolveForbiddenCommits: @escaping Try.Reply<Configuration.ResolveForbiddenCommits>,
    listFileLines: @escaping Try.Reply<Files.ListFileLines>,
    report: @escaping Try.Reply<Report>,
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
    try report(cfg.reportUnownedCode(files: files))
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
    try report(cfg.reportFileTabooIssues(issues: issues))
    return false
  }
  public func validateReviewObsolete(cfg: Configuration, target: String) throws -> Bool {
    var obsoleteFiles: [String] = []
    if let criteria = cfg.profile.obsolescence { obsoleteFiles += try Id(target)
      .map(Git.Branch.init(name:))
      .map(Git.Ref.make(remote:))
      .reduce(.head, cfg.git.listChangedOutsideFiles(source:target:))
      .map(execute)
      .map(Execute.parseLines(reply:))
      .get()
      .filter(criteria.isMet(_:))
    }
    var forbiddenCommits: [String] = []
    for sha in try resolveForbiddenCommits(.init(cfg: cfg)) {
      if case _? = try? execute(cfg.git.check(
        child: .head,
        parent: .make(sha: sha)
      )) { forbiddenCommits.append(sha.value) }
    }
    guard !obsoleteFiles.isEmpty || !forbiddenCommits.isEmpty else { return true }
    obsoleteFiles
      .map { $0 + ": obsolete" }
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    forbiddenCommits
      .map { "forbidden commit: " + $0 }
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    try report(cfg.reportReviewObsolete(
      obsoleteFiles: obsoleteFiles,
      forbiddenCommits: forbiddenCommits
    ))
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
    try report(cfg.reportConflictMarkers(markers: markers))
    return false
  }
}
