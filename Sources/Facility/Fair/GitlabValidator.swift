import Foundation
import Facility
import FacilityPure
public struct GitlabValidator {
  let execute: Try.Reply<Execute>
  let resolveCodeOwnage: Try.Reply<Configuration.ResolveCodeOwnage>
  let resolveFileTaboos: Try.Reply<Configuration.ResolveFileTaboos>
  let resolveForbiddenCommits: Try.Reply<Configuration.ResolveForbiddenCommits>
  let report: Try.Reply<Report>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveCodeOwnage: @escaping Try.Reply<Configuration.ResolveCodeOwnage>,
    resolveFileTaboos: @escaping Try.Reply<Configuration.ResolveFileTaboos>,
    resolveForbiddenCommits: @escaping Try.Reply<Configuration.ResolveForbiddenCommits>,
    report: @escaping Try.Reply<Report>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.resolveCodeOwnage = resolveCodeOwnage
    self.resolveFileTaboos = resolveFileTaboos
    self.resolveForbiddenCommits = resolveForbiddenCommits
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
      .map(Execute.successLines(reply:))
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
    let nameRules = rules.filter { $0.lines.isEmpty }
    let lineRules = rules.filter { !$0.lines.isEmpty }
    let files = try Id
      .make(Git.Ref.head)
      .map(cfg.git.listAllTrackedFiles(ref:))
      .map(execute)
      .map(Execute.successLines(reply:))
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
      try Id(file)
        .map(Files.Relative.init(value:))
        .reduce(.head, Git.File.init(ref:path:))
        .map(cfg.git.cat(file:))
        .map(execute)
        .map(Execute.successLines(reply:))
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
      .map(Execute.successLines(reply:))
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
      .map(Execute.successText(reply:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .get()
    _ = try Id
      .make(cfg.git.mergeBase(.head, .make(remote: .init(name: target))))
      .map(execute)
      .map(Execute.successText(reply:))
      .map(Git.Sha.init(value:))
      .map(Git.Ref.make(sha:))
      .map(cfg.git.resetSoft(ref:))
      .map(execute)
    let markers = try Id(cfg.git.listConflictMarkers)
      .map(execute)
      .map(Execute.successLines(reply:))
      .get()
    _ = try execute(cfg.git.resetHard(ref: initial))
    _ = try execute(cfg.git.clean)
    guard !markers.isEmpty else { return true }
    markers
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    try report(cfg.reportConflictMarkers(markers: markers))
    return false
  }
}
