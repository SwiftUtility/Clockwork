import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct Validator {
  public var handleFileList: Try.Reply<Git.HandleFileList>
  public var handleLine: Try.Reply<Git.HandleLine>
  public var handleVoid: Try.Reply<Git.HandleVoid>
  public var resolveAbsolutePath: Try.Reply<ResolveAbsolutePath>
  public var resolveGitlab: Try.Reply<ResolveGitlab>
  public var listFileLines: Try.Reply<ListFileLines>
  public var resolveFileApproval: Try.Reply<ResolveFileApproval>
  public var resolveFileRules: Try.Reply<ResolveFileRules>
  public var sendReport: Try.Reply<SendReport>
  public var logMessage: Act.Reply<LogMessage>
  public init(
    handleFileList: @escaping Try.Reply<Git.HandleFileList>,
    handleLine: @escaping Try.Reply<Git.HandleLine>,
    handleVoid: @escaping Try.Reply<Git.HandleVoid>,
    resolveAbsolutePath: @escaping Try.Reply<ResolveAbsolutePath>,
    resolveGitlab: @escaping Try.Reply<ResolveGitlab>,
    listFileLines: @escaping Try.Reply<ListFileLines>,
    resolveFileApproval: @escaping Try.Reply<ResolveFileApproval>,
    resolveFileRules: @escaping Try.Reply<ResolveFileRules>,
    sendReport: @escaping Try.Reply<SendReport>,
    logMessage: @escaping Act.Reply<LogMessage>
  ) {
    self.handleFileList = handleFileList
    self.handleLine = handleLine
    self.handleVoid = handleVoid
    self.resolveFileApproval = resolveFileApproval
    self.resolveFileRules = resolveFileRules
    self.resolveAbsolutePath = resolveAbsolutePath
    self.resolveGitlab = resolveGitlab
    self.listFileLines = listFileLines
    self.sendReport = sendReport
    self.logMessage = logMessage
  }
  public func validateUnownedCode(
    query: ValidateUnownedCode
  ) throws -> ValidateUnownedCode.Reply {
    let approvals = try Id(query.cfg)
      .reduce(invert: nil, ResolveFileApproval.init(cfg:profile:))
      .map(resolveFileApproval)
      .get()
      .or { throw Thrown("No fileOwnage in profile") }
    let issues = try Id
      .make(query.cfg.git)
      .reduce(curry: .head, Git.listAllTrackedFiles(ref:))
      .map(handleFileList)
      .get()
      .filter { file in !approvals.contains { $0.value.isMet(file) } }
      .map { "\($0) unowned" }
    return try report(cfg: query.cfg, issues: issues)
  }
  public func validateFileRules(
    query: ValidateFileRules
  ) throws -> ValidateFileRules.Reply {
    let rules = try resolveFileRules(.init(cfg: query.cfg, profile: nil))
    let nameRules = rules.filter { $0.lines.isEmpty }
    let lineRules = rules.filter { !$0.lines.isEmpty }
    let files = try Id
      .make(Git.Ref.head)
      .map(query.cfg.git.listAllTrackedFiles(ref:))
      .map(handleFileList)
      .get()
    var issues = query.cfg.fileRulesIssues
    for file in files {
      issues.issues += nameRules
        .filter { $0.files.isMet(file) }
        .map { .init(rule: $0.rule, file: file) }
      let lineRules = lineRules
        .filter { $0.files.isMet(file) }
      if lineRules.isEmpty { continue }
      issues.issues += try Id(file)
        .map(query.cfg.git.root.makeResolve(path:))
        .map(resolveAbsolutePath)
        .map(ListFileLines.init(file:))
        .map(listFileLines)
        .get()
        .enumerated()
        .flatMap { row, line in lineRules
          .filter { $0.lines.isMet(line) }
          .map { .init(rule: $0.rule, file: file, line: row) }
        }
    }
    guard !issues.issues.isEmpty else { return true }
    issues.issues
      .map(\.logMessage)
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    try sendReport(.init(cfg: query.cfg, report: .fileRulesIssues(issues)))
    return false
  }
  public func validateReviewTitle(
    query: ValidateReviewTitle
  ) throws -> ValidateReviewTitle.Reply {
    let titleRule = try query.cfg
      .getReview()
      .titleRule
      .or { throw Thrown("titleRule not configured") }
    guard titleRule.isMet(query.title) else { return true }
    return try report(cfg: query.cfg, issues: ["Invalid title: \(query.title)"])
  }
  public func validateReviewObsolete(
    query: ValidateReviewObsolete
  ) throws -> ValidateReviewObsolete.Reply {
    let obsolete = try query.cfg.profile.obsolete
      .or { throw Thrown("no obsolete in profile") }
    let files = try handleFileList(query.cfg.git.listChangedOutsideFiles(
      source: .head,
      target: .make(remote: .init(name: query.target))
    ))
    var issues: [String] = []
    for file in files {
      guard obsolete.isMet(file) else { continue }
      issues.append("\(file): Changes not included")
    }
    return try report(cfg: query.cfg, issues: issues)
  }
  public func validateReviewConflictMarkers(
    query: ValidateReviewConflictMarkers
  ) throws -> ValidateReviewConflictMarkers.Reply {
    let initial = try Git.Ref.make(sha: .init(ref: handleLine(query.cfg.git.getSha(ref: .head))))
    let base = try handleLine(query.cfg.git.mergeBase(
      .head,
      .make(remote: .init(name: query.target))
    ))
    try handleVoid(query.cfg.git.resetSoft(ref: .make(sha: .init(ref: base))))
    let issues = try handleLine(query.cfg.git.listConflictMarkers)
      .components(separatedBy: .newlines)
    try handleVoid(query.cfg.git.resetHard(ref: initial))
    try handleVoid(query.cfg.git.clean)
    return try report(cfg: query.cfg, issues: issues)
  }
}
extension Validator {
  func report(cfg: Configuration, issues: [String]) throws -> Bool {
    guard !issues.isEmpty else { return true }
    issues
      .map(LogMessage.init(message:))
      .forEach(logMessage)
    try sendReport(.init(cfg: cfg, report: .validationIssues(issues)))
    return false
  }
}
