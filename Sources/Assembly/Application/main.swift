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
    execute: Processor.execute(query:),
    logLine: FileHandle.standardError.write(message:),
    printLine: FileHandle.standardOutput.write(message:),
    getTime: Date.init,
    renderStencil: stencilParser.renderStencil(query:)
  )
  static let configurator = Configurator(
    execute: Processor.execute(query:),
    decodeYaml: YamlParser.decodeYaml(query:),
    resolveAbsolutePath: Finder.resolveAbsolutePath(query:),
    readFile: Finder.readFile(query:),
    renderStencil: stencilParser.renderStencil(query:),
    writeData: Finder.writeData(query:),
    logMessage: reporter.logMessage(query:),
    printLine: FileHandle.standardOutput.write(message:),
    dialect: .json
  )
  static let environment = ProcessInfo.processInfo.environment
  static let validator = GitlabValidator(
    execute: Processor.execute(query:),
    resolveCodeOwnage: configurator.resolveCodeOwnage(query:),
    resolveFileTaboos: configurator.resolveFileTaboos(query:),
    sendReport: reporter.sendReport(query:),
    logMessage: reporter.logMessage(query:),
    jsonDecoder: jsonDecoder
  )
  static let requisitor = Requisitor(
    execute: Processor.execute(query:),
    resolveAbsolutePath: Finder.resolveAbsolutePath(query:),
    resolveRequisition: configurator.resolveRequisition(query:),
    plistDecoder: .init()
  )
  static let gitlabAwardApprover = GitlabAwardApprover(
    execute: Processor.execute(query:),
    resolveProfile: configurator.resolveProfile(query:),
    resolveAwardApproval: configurator.resolveAwardApproval(query:),
    resolveAwardApprovalUserActivity: configurator.resolveAwardApprovalUserActivity(query:),
    resolveCodeOwnage: configurator.resolveCodeOwnage(query:),
    persistUserActivity: configurator.persistUserActivity(query:),
    resolveFlow: configurator.resolveFlow(query:),
    sendReport: reporter.sendReport(query:),
    logMessage: reporter.logMessage(query:),
    jsonDecoder: jsonDecoder
  )
  static let gitlabMerger = GitlabMerger(
    execute: Processor.execute(query:),
    resolveFlow: configurator.resolveFlow(query:),
    printLine: FileHandle.standardOutput.write(message:),
    renderStencil: stencilParser.renderStencil(query:),
    sendReport: reporter.sendReport(query:),
    logMessage: reporter.logMessage(query:),
    jsonDecoder: jsonDecoder
  )
  static let gitlabCommunicatior = GitlabMediator(
    execute: Processor.execute(query:),
    logMessage: reporter.logMessage(query:),
    jsonDecoder: jsonDecoder
  )
  static let gitlabVersionController = GitlabVersionController(
    execute: Processor.execute(query:),
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
    jsonDecoder: jsonDecoder
  )
  static let stencilParser = StencilParser(notation: .json)
  static let jsonDecoder: JSONDecoder = {
    let result = JSONDecoder()
    result.keyDecodingStrategy = .convertFromSnakeCase
    return result
  }()
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
