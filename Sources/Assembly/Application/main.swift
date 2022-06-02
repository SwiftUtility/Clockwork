import Foundation
import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
import FacilityWorkers
import InteractivityCommon
import InteractivityYams
import InteractivityStencil
import InteractivityPathKit
enum Main {
  static let version = "0.0.1"
  static let configurator = Configurator(
    decodeYaml: YamlParser.decodeYaml(query:),
    resolveAbsolutePath: Finder.resolveAbsolutePath(query:),
    readFile: Finder.readFile(query:),
    gitHandleFileList: Processor.handleProcess(query:),
    gitHandleLine: Processor.handleProcess(query:),
    gitHandleCat: Processor.handleProcess(query:),
    gitHandleVoid: Processor.handleProcess(query:)
  )
  static let reporter = Reporter(
    logLine: FileHandle.standardError.write(message:),
    printLine: FileHandle.standardOutput.write(message:),
    getTime: Date.init,
    renderStencil: stencilParser.renderStencil(query:),
    handleSlackHook: Processor.handleProcess(query:)
  )
  static let environment = ProcessInfo.processInfo.environment
  static let validator = Validator(
    handleFileList: Processor.handleProcess(query:),
    handleLine: Processor.handleProcess(query:),
    handleVoid: Processor.handleProcess(query:),
    resolveAbsolutePath: Finder.resolveAbsolutePath(query:),
    resolveGitlab: configurator.resolveGitlab(query:),
    listFileLines: FileLiner.listFileLines(query:),
    resolveFileApproval: configurator.resolveFileApproval(query:),
    resolveFileRules: configurator.resolveFileRules(query:),
    sendReport: reporter.sendReport(query:),
    logMessage: reporter.logMessage(query:)
  )
  static let laborer = Laborer(
    handleFileList: Processor.handleProcess(query:),
    handleLine: Processor.handleProcess(query:),
    handleVoid: Processor.handleProcess(query:),
    getReviewState: Processor.handleProcess(query:),
    getReviewAwarders: Processor.handleProcess(query:),
    postPipelines: Processor.handleProcess(query:),
    postReviewAward: Processor.handleProcess(query:),
    putMerge: Processor.handleProcess(query:),
    putRebase: Processor.handleProcess(query:),
    putState: Processor.handleProcess(query:),
    getPipeline: Processor.handleProcess(query:),
    postTriggerPipeline: Processor.handleProcess(query:),
    postMergeRequests: Processor.handleProcess(query:),
    listShaMergeRequests: Processor.handleProcess(query:),
    renderStencil: stencilParser.renderStencil(query:),
    resolveGitlab: configurator.resolveGitlab(query:),
    resolveProfile: configurator.resolveProfile(query:),
    resolveFileApproval: configurator.resolveFileApproval(query:),
    resolveAwardApproval: configurator.resolveAwardApproval(query:),
    sendReport: reporter.sendReport(query:),
    logMessage: reporter.logMessage(query:),
    printLine: FileHandle.standardOutput.write(message:)
  )
  static let stencilParser = StencilParser(notation: .json)
}
MayDay.sideEffect = { mayDay in FileHandle.standardError.write(
  message: """
    ⚠️⚠️⚠️
    Please submit an issue at https://github.com/VladimirBorodko/team-builder/issues/new/choose
    Version: \(Main.version)
    What: \(mayDay.what)
    File: \(mayDay.file)
    Line: \(mayDay.line)
    ⚠️⚠️⚠️
    """
)}
Clockwork.main()
