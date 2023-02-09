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
//    parseSlackStorage: configurator.parseYamlFile(query:),
    logMessage: logger.logMessage(query:),
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
    parseFileTaboos: configurator.parseYamlFile(query:),
    listFileLines: FileLiner.listFileLines(query:),
    logMessage: logger.logMessage(query:),
    stdoutData: stdoutData,
    jsonDecoder: jsonDecoder
  )
  static let requisitor = Requisitor(
    execute: execute,
    resolveAbsolute: Finder.resolveAbsolute(query:),
    parseRequisition: configurator.parseYamlFile(query:),
    resolveSecret: configurator.resolveSecret(query:),
    parseCocoapods: configurator.parseYamlFile(query:),
    writeFile: Finder.writeFile(query:),
    listFileSystem: Finder.listFileSystem(query:),
    getTime: Date.init,
    plistDecoder: .init()
  )
  static let reviewer = Reviewer(
    execute: execute,
    parseReview: configurator.parseYamlFile(query:),
    parseReviewStorage: configurator.parseYamlFile(query:),
    parseReviewRules: configurator.parseYamlSecret(query:),
    parseCodeOwnage: configurator.parseYamlFile(query:),
    parseProfile: configurator.parseYamlFile(query:),
    persistAsset: configurator.persistAsset(query:),
    writeStdout: writeStdout,
    generate: stencilParser.generate(query:),
    parseStdin: reporter.parseStdin(query:),
    readStdin: readStdin,
    logMessage: logger.logMessage(query:),
    jsonDecoder: jsonDecoder
  )
  static let mediator = Mediator(
    execute: execute,
    parseReview: configurator.parseYamlFile(query:),
    parseReviewRules: configurator.parseYamlSecret(query:),
    parseReviewStorage: configurator.parseYamlFile(query:),
    parseFlow: configurator.parseYamlFile(query:),
    parseFlowVersions: configurator.parseYamlFile(query:),
    registerSlackUser: slacker.registerSlackUser(query:),
    persistAsset: configurator.persistAsset(query:),
    parseStdin: reporter.parseStdin(query:),
    generate: stencilParser.generate(query:),
    logMessage: logger.logMessage(query:),
    stdoutData: stdoutData,
    jsonDecoder: jsonDecoder
  )
  static let producer = Producer(
    execute: execute,
    generate: stencilParser.generate(query:),
    writeFile: Finder.writeFile(query:),
    parseFlow: configurator.parseYamlFile(query:),
    parseFlowBuilds: configurator.parseYamlFile(query:),
    parseFlowVersions: configurator.parseYamlFile(query:),
    persistAsset: configurator.persistAsset(query:),
    logMessage: logger.logMessage(query:),
    writeStdout: writeStdout,
    jsonDecoder: jsonDecoder
  )
  static let slacker = Slacker(
    parseSlackStorage: configurator.parseYamlFile(query:),
    persistAsset: configurator.persistAsset(query:)
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
