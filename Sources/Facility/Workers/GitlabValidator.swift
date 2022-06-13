import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct GitlabValidator {
  let handleApi: Try.Reply<GitlabCi.HandleApi>
  let handleFileList: Try.Reply<Git.HandleFileList>
  let handleLine: Try.Reply<Git.HandleLine>
  let handleVoid: Try.Reply<Git.HandleVoid>
  let handleCat: Try.Reply<Git.HandleCat>
  let resolveCodeOwnage: Try.Reply<ResolveCodeOwnage>
  let resolveFileTaboos: Try.Reply<ResolveFileTaboos>
  let sendReport: Try.Reply<SendReport>
  let logMessage: Act.Reply<LogMessage>
  let dialect: AnyCodable.Dialect
  public init(
    handleApi: @escaping Try.Reply<GitlabCi.HandleApi>,
    handleFileList: @escaping Try.Reply<Git.HandleFileList>,
    handleLine: @escaping Try.Reply<Git.HandleLine>,
    handleVoid: @escaping Try.Reply<Git.HandleVoid>,
    handleCat: @escaping Try.Reply<Git.HandleCat>,
    resolveCodeOwnage: @escaping Try.Reply<ResolveCodeOwnage>,
    resolveFileTaboos: @escaping Try.Reply<ResolveFileTaboos>,
    sendReport: @escaping Try.Reply<SendReport>,
    logMessage: @escaping Act.Reply<LogMessage>,
    dialect: AnyCodable.Dialect
  ) {
    self.handleApi = handleApi
    self.handleFileList = handleFileList
    self.handleLine = handleLine
    self.handleVoid = handleVoid
    self.handleCat = handleCat
    self.resolveCodeOwnage = resolveCodeOwnage
    self.resolveFileTaboos = resolveFileTaboos
    self.sendReport = sendReport
    self.logMessage = logMessage
    self.dialect = dialect
  }
  public func validateUnownedCode(cfg: Configuration) throws -> Bool {
    let approvals = try Id(cfg.profile)
      .reduce(cfg, ResolveCodeOwnage.init(cfg:profile:))
      .map(resolveCodeOwnage)
      .get()
    let files = try Id
      .make(cfg.git)
      .reduce(curry: .head, Git.listAllTrackedFiles(ref:))
      .map(handleFileList)
      .get()
      .filter { file in !approvals.contains { $0.value.isMet(file) } }
    guard !files.isEmpty else { return true }
    files
      .map { $0 + ": unowned" }
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    try cfg.controls.gitlabCi
      .flatMap(\.getCurrentJob)
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
      .reduce(invert: files, cfg.reportUnownedCode(job:files:))
      .map(cfg.makeSendReport(report:))
      .map(sendReport)
      .get()
    return false
  }
  public func validateFileTaboos(cfg: Configuration) throws -> Bool {
    let rules = try resolveFileTaboos(.init(cfg: cfg, profile: cfg.profile))
    let nameRules = rules.filter { $0.lines.isEmpty }
    let lineRules = rules.filter { !$0.lines.isEmpty }
    let files = try Id
      .make(Git.Ref.head)
      .map(cfg.git.listAllTrackedFiles(ref:))
      .map(handleFileList)
      .get()
    var issues: [FileTaboo.Issue] = []
    for file in files {
      issues += nameRules
        .filter { $0.files.isMet(file) }
        .map { .init(rule: $0.rule, file: file) }
      let lineRules = lineRules
        .filter { $0.files.isMet(file) }
      if lineRules.isEmpty { continue }
      issues += try Id(file)
        .map(Path.Relative.init(value:))
        .reduce(.head, Git.File.init(ref:path:))
        .map(cfg.git.cat(file:))
        .map(handleCat)
        .map(String.make(utf8:))
        .get()
        .components(separatedBy: .newlines)
        .enumerated()
        .flatMap { row, line in lineRules
          .filter { $0.lines.isMet(line) }
          .map { .init(rule: $0.rule, file: file, line: row) }
        }
    }
    guard !issues.isEmpty else { return true }
    issues
      .map(\.logMessage)
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    try cfg.controls.gitlabCi
      .flatMap(\.getCurrentJob)
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
      .reduce(invert: issues, cfg.reportFileTabooIssues(job:issues:))
      .map(cfg.makeSendReport(report:))
      .map(sendReport)
      .get()
    return false
  }
  public func validateReviewObsolete(cfg: Configuration, target: String) throws -> Bool {
    var obsoleteFiles: [String] = []
    if let criteria = cfg.profile.obsolescence { obsoleteFiles += try Id(target)
      .map(Git.Branch.init(name:))
      .map(Git.Ref.make(remote:))
      .reduce(.head, cfg.git.listChangedOutsideFiles(source:target:))
      .map(handleFileList)
      .get()
      .filter(criteria.isMet(_:))
    }
    var forbiddenCommits: [String] = []
    for sha in cfg.controls.forbiddenCommits {
      if case ()? = try? handleVoid(cfg.git.check(
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
    let job = try cfg.controls.gitlabCi
      .flatMap(\.getCurrentJob)
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
      .get()
    try sendReport(cfg.makeSendReport(report: cfg.reportReviewObsolete(
      job: job,
      obsoleteFiles: obsoleteFiles,
      forbiddenCommits: forbiddenCommits
    )))
    return false
  }
  public func validateReviewConflictMarkers(cfg: Configuration, target: String) throws -> Bool {
    let initial = try Git.Ref.make(sha: .init(value: handleLine(cfg.git.getSha(ref: .head))))
    let base = try handleLine(cfg.git.mergeBase(
      .head,
      .make(remote: .init(name: target))
    ))
    try handleVoid(cfg.git.resetSoft(ref: .make(sha: .init(value: base))))
    let markers = try handleLine(cfg.git.listConflictMarkers)
      .components(separatedBy: .newlines)
    try handleVoid(cfg.git.resetHard(ref: initial))
    try handleVoid(cfg.git.clean)

    guard !markers.isEmpty else { return true }
    markers
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    try cfg.controls.gitlabCi
      .flatMap(\.getCurrentJob)
      .map(handleApi)
      .reduce(Json.GitlabJob.self, dialect.read(_:from:))
      .reduce(invert: markers, cfg.reportConflictMarkers(job:markers:))
      .map(cfg.makeSendReport(report:))
      .map(sendReport)
      .get()
    return false
  }
}
