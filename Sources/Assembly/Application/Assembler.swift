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
    resolveCodeOwnage: configurator.resolveCodeOwnage(query:),
    resolveFileTaboos: configurator.resolveFileTaboos(query:),
    listFileLines: FileLiner.listFileLines(query:),
    logMessage: logger.logMessage(query:),
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
//  static let approver = Approver(
//    execute: execute,
//    resolveProfile: configurator.resolveProfile(query:),
//    resolveAwardApproval: configurator.resolveAwardApproval(query:),
//    resolveUserActivity: configurator.resolveUserActivity(query:),
//    resolveCodeOwnage: configurator.resolveCodeOwnage(query:),
//    persistUserActivity: configurator.persistUserActivity(query:),
//    resolveFusion: configurator.resolveFusion(query:),
//    report: reporter.report(query:),
//    logMessage: logger.logMessage(query:),
//    worker: worker,
//    jsonDecoder: jsonDecoder
//  )
  static let merger = Merger(
    execute: execute,
    resolveFusion: configurator.resolveFusion(query:),
    resolveFusionStatuses: configurator.resolveFusionStatuses(query:),
    persistFusionStatuses: configurator.persistFusionStatuses(query:),
    resolveReviewQueue: configurator.resolveReviewQueue(query:),
    persistReviewQueue: configurator.persistReviewQueue(query:),
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
    resolveProductionVersions: configurator.resolveProductionVersions(query:),
    resolveProductionBuilds: configurator.resolveProductionBuilds(query:),
    persistBuilds: configurator.persistBuilds(query:),
    persistVersions: configurator.persistVersions(query:),
    report: reporter.report(query:),
    logMessage: logger.logMessage(query:),
    writeStdout: writeStdout,
    worker: worker,
    jsonDecoder: jsonDecoder
  )
  static let porter = Porter(
    execute: execute,
    resolveReviewQueue: configurator.resolveReviewQueue(query:),
    persistReviewQueue: configurator.persistReviewQueue(query:),
    logMessage: logger.logMessage(query:),
    worker: worker
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
  static let writeStderr = FileHandle.standardError.write(message:)
  static let readStdin = FileHandle.readStdin
  static let execute = Processor.execute(query:)
}
