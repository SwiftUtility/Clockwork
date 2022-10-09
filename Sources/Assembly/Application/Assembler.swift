import Foundation
import FacilityFair
import InteractivityCommon
import InteractivityYams
import InteractivityStencil
import InteractivityPathKit
enum Assembler {
  static let logger = Logger(
    writeStderr: writeStderr,
    getTime: Date.init
  )
  static let reporter = Reporter(
    execute: execute,
    writeStdout: writeStdout,
    readStdin: readStdin,
    generate: stencilParser.generate(query:),
    resolveFusion: configurator.resolveFusion(query:),
    resolveFusionStatuses: configurator.resolveFusionStatuses(query:),
    resolveApprovers: configurator.resolveApprovers(query:),
    logMessage: logger.logMessage(query:),
    worker: worker,
    jsonDecoder: jsonDecoder
  )
  static let configurator = Configurator(
    execute: execute,
    decodeYaml: YamlParser.decodeYaml(query:),
    resolveAbsolute: Finder.resolveAbsolute(query:),
    readFile: Finder.readFile(query:),
    generate: stencilParser.generate(query:),
    writeFile: Finder.writeFile(query:),
    logMessage: logger.logMessage(query:),
    dialect: .json,
    jsonDecoder: jsonDecoder
  )
  static let environment = ProcessInfo.processInfo.environment
  static let validator = Validator(
    execute: execute,
    parseCodeOwnage: configurator.parseYamlFile(query:),
    resolveFileTaboos: configurator.resolveFileTaboos(query:),
    listFileLines: FileLiner.listFileLines(query:),
    logMessage: logger.logMessage(query:),
    stdoutData: stdoutData,
    jsonDecoder: jsonDecoder
  )
  static let requisitor = Requisitor(
    execute: execute,
    report: reporter.report(query:),
    resolveAbsolute: Finder.resolveAbsolute(query:),
    resolveRequisition: configurator.resolveRequisition(query:),
    resolveSecret: configurator.resolveSecret(query:),
    resolveCocoapods: configurator.resolveCocoapods(query:),
    persistCocoapods: configurator.persistCocoapods(query:),
    listFileSystem: Finder.listFileSystem(query:),
    getTime: Date.init,
    plistDecoder: .init()
  )
  static let reviewer = Reviewer(
    execute: execute,
    resolveFusion: configurator.resolveFusion(query:),
    resolveFusionStatuses: configurator.resolveFusionStatuses(query:),
    resolveReviewQueue: configurator.resolveReviewQueue(query:),
    resolveApprovers: configurator.resolveApprovers(query:),
    parseApprovalRules: configurator.parseYamlFile(query:),
    parseCodeOwnage: configurator.parseYamlFile(query:),
    parseProfile: configurator.parseYamlFile(query:),
    parseAntagonists: configurator.parseYamlSecret(query:),
    persistAsset: configurator.persistAsset(query:),
    writeStdout: writeStdout,
    generate: stencilParser.generate(query:),
    report: reporter.report(query:),
    createThread: reporter.createThread(query:),
    logMessage: logger.logMessage(query:),
    worker: worker,
    jsonDecoder: jsonDecoder
  )
  static let mediator = Mediator(
    execute: execute,
    logMessage: logger.logMessage(query:),
    worker: worker,
    jsonDecoder: jsonDecoder
  )
  static let producer = Producer(
    execute: execute,
    generate: stencilParser.generate(query:),
    writeFile: Finder.writeFile(query:),
    resolveProduction: configurator.resolveProduction(query:),
    resolveProductionBuilds: configurator.resolveProductionBuilds(query:),
    parseVersions: configurator.parseYamlFile(query:),
    persistAsset: configurator.persistAsset(query:),
    report: reporter.report(query:),
    createThread: reporter.createThread(query:),
    logMessage: logger.logMessage(query:),
    writeStdout: writeStdout,
    worker: worker,
    jsonDecoder: jsonDecoder
  )
  static let worker = Worker(
    execute: execute,
    logMessage: logger.logMessage(query:),
    jsonDecoder: jsonDecoder
  )
  static let stencilParser = StencilParser(notation: .json)
  static let jsonDecoder: JSONDecoder = {
    let result = JSONDecoder()
    result.keyDecodingStrategy = .convertFromSnakeCase
    return result
  }()
  static let writeStdout = FileHandle.standardOutput.write(message:)
  static let stdoutData = FileHandle.standardOutput.write(data:)
  static let writeStderr = FileHandle.standardError.write(message:)
  static let readStdin = FileHandle.readStdin
  static let execute = Processor.execute(query:)
}
