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
  static let reporter = Reporter(
    logLine: FileHandle.standardError.write(message:),
    printLine: FileHandle.standardOutput.write(message:),
    getTime: Date.init,
    renderStencil: stencilParser.renderStencil(query:),
    handleSlackHook: Processor.handleProcess(query:)
  )
  static let configurator = Configurator(
    decodeYaml: YamlParser.decodeYaml(query:),
    resolveAbsolutePath: Finder.resolveAbsolutePath(query:),
    readFile: Finder.readFile(query:),
    handleFileList: Processor.handleProcess(query:),
    handleLine: Processor.handleProcess(query:),
    handleCat: Processor.handleProcess(query:),
    handleVoid: Processor.handleProcess(query:),
    renderStencil: stencilParser.renderStencil(query:),
    writeData: Finder.writeData(query:),
    logMessage: reporter.logMessage(query:),
    printLine: FileHandle.standardOutput.write(message:),
    dialect: .json
  )
  static let environment = ProcessInfo.processInfo.environment
  static let validator = GitlabValidator(
    handleApi: Processor.handleProcess(query:),
    handleFileList: Processor.handleProcess(query:),
    handleLine: Processor.handleProcess(query:),
    handleVoid: Processor.handleProcess(query:),
    handleCat: Processor.handleProcess(query:),
    resolveCodeOwnage: configurator.resolveCodeOwnage(query:),
    resolveFileTaboos: configurator.resolveFileTaboos(query:),
    sendReport: reporter.sendReport(query:),
    logMessage: reporter.logMessage(query:),
    dialect: .json
  )
  static let requisitor = Requisitor()
  static let gitlabAwardApprover = GitlabAwardApprover(
    handleFileList: Processor.handleProcess(query:),
    handleLine: Processor.handleProcess(query:),
    handleVoid: Processor.handleProcess(query:),
    handleApi: Processor.handleProcess(query:),
    resolveProfile: configurator.resolveProfile(query:),
    resolveAwardApproval: configurator.resolveAwardApproval(query:),
    resolveAwardApprovalUserActivity: configurator.resolveAwardApprovalUserActivity(query:),
    resolveCodeOwnage: configurator.resolveCodeOwnage(query:),
    persistUserActivity: configurator.persistUserActivity(query:),
    resolveFlow: configurator.resolveFlow(query:),
    sendReport: reporter.sendReport(query:),
    logMessage: reporter.logMessage(query:),
    dialect: .json
  )
  static let gitlabMerger = GitlabMerger(
    handleApi: Processor.handleProcess(query:),
    handleVoid: Processor.handleProcess(query:),
    handleLine: Processor.handleProcess(query:),
    resolveFlow: configurator.resolveFlow(query:),
    printLine: FileHandle.standardOutput.write(message:),
    renderStencil: stencilParser.renderStencil(query:),
    sendReport: reporter.sendReport(query:),
    logMessage: reporter.logMessage(query:),
    dialect: .json
  )
  static let gitlabCommunicatior = GitlabMediator(
    handleApi: Processor.handleProcess(query:),
    logMessage: reporter.logMessage(query:),
    dialect: .json
  )
  static let gitlabVersionController = GitlabVersionController(
    handleApi: Processor.handleProcess(query:),
    handleVoid: Processor.handleProcess(query:),
    handleLine: Processor.handleProcess(query:),
    renderStencil: stencilParser.renderStencil(query:),
    writeData: Finder.writeData(query:),
    resolveProduction: configurator.resolveProduction(query:),
    resolveProductionVersions: configurator.resolveProductionVersions(query:),
    resolveProductionBuilds: configurator.resolveProductionBuilds(query:),
    persistBuilds: configurator.persistBuilds(query:),
    persistVersions: configurator.persistVersions(query:),
    sendReport: reporter.sendReport(query:),
    logMessage: reporter.logMessage(query:),
    printLine: FileHandle.standardOutput.write(message:),
    dialect: .json
  )
  static let stencilParser = StencilParser(notation: .json)
}
MayDay.sideEffect = { mayDay in FileHandle.standardError.write(
  message: """
    ⚠️⚠️⚠️
    Please submit an issue at https://github.com/SwiftUtility/Clockwork/issues/new/choose
    Version: \(Main.version)
    What: \(mayDay.what)
    File: \(mayDay.file)
    Line: \(mayDay.line)
    ⚠️⚠️⚠️
    """
)}
Clockwork.main()
