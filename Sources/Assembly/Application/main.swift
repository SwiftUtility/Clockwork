import Foundation
import Foundation
import Facility
import FacilityPure
import FacilityFair
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
    readInput: FileHandle.readStdin,
    generate: stencilParser.generate(query:),
    jsonDecoder: jsonDecoder
  )
  static let configurator = Configurator(
    execute: Processor.execute(query:),
    decodeYaml: YamlParser.decodeYaml(query:),
    resolveAbsolute: Finder.resolveAbsolute(query:),
    readFile: Finder.readFile(query:),
    generate: stencilParser.generate(query:),
    writeFile: Finder.writeFile(query:),
    logMessage: reporter.logMessage(query:),
    printLine: FileHandle.standardOutput.write(message:),
    dialect: .json,
    jsonDecoder: jsonDecoder
  )
  static let environment = ProcessInfo.processInfo.environment
  static let validator = GitlabValidator(
    execute: Processor.execute(query:),
    resolveCodeOwnage: configurator.resolveCodeOwnage(query:),
    resolveFileTaboos: configurator.resolveFileTaboos(query:),
    resolveForbiddenCommits: configurator.resolveForbiddenCommits(query:),
    listFileLines: FileLiner.listFileLines(query:),
    report: reporter.report(query:),
    logMessage: reporter.logMessage(query:),
    jsonDecoder: jsonDecoder
  )
  static let requisitor = Requisitor(
    execute: Processor.execute(query:),
    report: reporter.report(query:),
    resolveAbsolute: Finder.resolveAbsolute(query:),
    resolveRequisition: configurator.resolveRequisition(query:),
    resolveSecret: configurator.resolveSecret(query:),
    getTime: Date.init,
    plistDecoder: .init()
  )
  static let gitlabAwardApprover = GitlabAwardApprover(
    execute: Processor.execute(query:),
    resolveProfile: configurator.resolveProfile(query:),
    resolveAwardApproval: configurator.resolveAwardApproval(query:),
    resolveUserActivity: configurator.resolveUserActivity(query:),
    resolveCodeOwnage: configurator.resolveCodeOwnage(query:),
    persistUserActivity: configurator.persistUserActivity(query:),
    resolveFlow: configurator.resolveFlow(query:),
    report: reporter.report(query:),
    logMessage: reporter.logMessage(query:),
    jsonDecoder: jsonDecoder
  )
  static let gitlabMerger = GitlabMerger(
    execute: Processor.execute(query:),
    resolveFlow: configurator.resolveFlow(query:),
    printLine: FileHandle.standardOutput.write(message:),
    generate: stencilParser.generate(query:),
    report: reporter.report(query:),
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
    generate: stencilParser.generate(query:),
    writeFile: Finder.writeFile(query:),
    resolveProduction: configurator.resolveProduction(query:),
    resolveProductionVersions: configurator.resolveProductionVersions(query:),
    resolveProductionBuilds: configurator.resolveProductionBuilds(query:),
    persistBuilds: configurator.persistBuilds(query:),
    persistVersions: configurator.persistVersions(query:),
    report: reporter.report(query:),
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
