import ArgumentParser
import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
struct Clockwork: ParsableCommand {
  @Option(help: "The path to the profile")
  var profile = ".clockwork.yml"
  @Flag(help: "Should log everything")
  var verbose = false
  static let configuration = CommandConfiguration(
    abstract: "Distributed scalable monorepo management tool",
    version: Main.version,
    subcommands: [
      CheckUnownedCode.self,
      CheckFileRules.self,
      CheckGitlabReviewConflictMarkers.self,
      CheckGitlabReviewObsolete.self,
      CheckGitlabReviewTitle.self,
      CheckGitlabReviewApproval.self,
      CheckGitlabReplicationApproval.self,
      CheckGitlabIntegrationApproval.self,
      AddGitlabReviewLabels.self,
      AcceptGitlabReview.self,
      TriggerGitlabTargetPipeline.self,
      PerformGitlabReplication.self,
    ]
  )
  struct CheckUnownedCode: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Ensure no unowned files" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.validator.validateUnownedCode(
        query: .init(cfg: configuration)
      )
    }
  }
  struct CheckFileRules: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Ensure files match defined rules" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.validator.validateFileRules(
        query: .init(cfg: configuration)
      )
    }
  }
  struct CheckGitlabReviewConflictMarkers: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Argument var target: String
    static var abstract: String { "Ensure no conflict markers" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.validator.validateReviewConflictMarkers(
        query: .init(cfg: configuration, target: target)
      )
    }
  }
  struct CheckGitlabReviewObsolete: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Argument var target: String
    static var abstract: String { "Ensure source is in sync with target" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.validator.validateReviewObsolete(
        query: .init(cfg: configuration, target: target)
      )
    }
  }
  struct CheckGitlabReviewTitle: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Argument var title: String
    static var abstract: String { "Ensure title matches defined rules" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.validator.validateReviewTitle(
        query: .init(cfg: configuration, title: title)
      )
    }
  }
  struct CheckGitlabReviewApproval: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Check approval state and report new involved" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.checkApproval(
        query: .init(cfg: configuration, mode: .review)
      )
    }
  }
  struct AddGitlabReviewLabels: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Argument var labels: [String]
    static var abstract: String { "Add labels to review" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.labelGitlabReview(
        query: .init(labels: labels, cfg: configuration)
      )
    }
  }
  struct AcceptGitlabReview: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Rebase and accept review" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.acceptReview(
        query: .init(cfg: configuration)
      )
    }
  }
  struct TriggerGitlabTargetPipeline: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
    var context: [String] = []
    static var abstract: String { "Trigger pipeline on target branch" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.triggerTargetPipeline(
        query: .init(context: context, cfg: configuration)
      )
    }
  }
  struct CheckGitlabReplicationApproval: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Check approval state and report new involved" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.checkApproval(
        query: .init(cfg: configuration, mode: .replication)
      )
    }
  }
  struct PerformGitlabReplication: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Create replication branch and review" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.performReplication(
        query: .init(cfg: configuration)
      )
    }
  }
  struct CheckGitlabIntegrationApproval: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Check approval state and report new involved" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.checkApproval(
        query: .init(cfg: configuration, mode: .integration)
      )
    }
  }
}
protocol ClockworkCommand: ParsableCommand {
  var arguments: Clockwork { get }
  static var abstract: String { get }
  func run(configuration: Configuration) throws -> Bool
}
extension ClockworkCommand {
  static var configuration: CommandConfiguration {
    .init(abstract: abstract)
  }
  mutating func run() throws {
    let context = try Main.configurator.resolveConfiguration(query: .init(
      profile: arguments.profile,
      verbose: arguments.verbose,
      env: Main.environment
    ))
    try Lossy(context)
      .map(run(configuration:))
      .reduceError(context, Main.reporter.report(cfg:error:))
      .reduce(context, Main.reporter.finish(cfg:success:))
      .get()
  }
}
