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
      CheckReviewConflictMarkers.self,
      CheckReviewObsolete.self,
      CheckReviewTitle.self,
      CheckGitlabReviewAwardApproval.self,
      CheckGitlabReplicationAwardApproval.self,
      CheckGitlabIntegrationAwardApproval.self,
      AddGitlabReviewLabels.self,
      AcceptGitlabReview.self,
      TriggerGitlabPipeline.self,
      PerformGitlabReplication.self,
      GenerateGitlabIntegrationJobs.self,
      PerformGitlabIntegration.self,
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
  struct CheckReviewConflictMarkers: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Argument(help: "the branch to diff with")
    var target: String
    static var abstract: String { "Ensure no conflict markers" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.validator.validateReviewConflictMarkers(
        query: .init(cfg: configuration, target: target)
      )
    }
  }
  struct CheckReviewObsolete: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Argument(help: "the branch to check obsolence against")
    var target: String
    static var abstract: String { "Ensure source is in sync with target" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.validator.validateReviewObsolete(
        query: .init(cfg: configuration, target: target)
      )
    }
  }
  struct CheckReviewTitle: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Argument(help: "Title to be validated")
    var title: String
    static var abstract: String { "Ensure title matches defined rules" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.validator.validateReviewTitle(
        query: .init(cfg: configuration, title: title)
      )
    }
  }
  struct CheckGitlabReviewAwardApproval: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Check approval state and report new involved" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.checkAwardApproval(
        query: .init(cfg: configuration, mode: .review)
      )
    }
  }
  struct AddGitlabReviewLabels: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Argument(help: "Labels to be added to triggerer review")
    var labels: [String]
    static var abstract: String { "Add labels to triggerer review" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.addReviewLabels(
        query: .init(cfg: configuration, labels: labels)
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
  struct TriggerGitlabPipeline: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    @Option(help: "Ref to run pipeline on")
    var ref: String
    @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
    var context: [String] = []
    static var abstract: String { "Trigger pipeline and pass context" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.triggerTargetPipeline(
        query: .init(cfg: configuration, ref: ref, context: context)
      )
    }
  }
  struct CheckGitlabReplicationAwardApproval: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Check approval state and report new involved" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.checkAwardApproval(
        query: .init(cfg: configuration, mode: .replication)
      )
    }
  }
  struct PerformGitlabReplication: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Create and accept replication branch and review" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.performReplication(
        query: .init(cfg: configuration)
      )
    }
  }
  struct CheckGitlabIntegrationAwardApproval: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Check approval state and report new involved" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.checkAwardApproval(
        query: .init(cfg: configuration, mode: .integration)
      )
    }
  }
  struct GenerateGitlabIntegrationJobs: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Stdouts rendered job template for suitable branches" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.generateIntegrationJobs(
        query: .init(cfg: configuration)
      )
    }
  }
  struct PerformGitlabIntegration: ClockworkCommand {
    @OptionGroup var arguments: Clockwork
    static var abstract: String { "Create and accept integration branch and review" }
    func run(configuration: Configuration) throws -> Bool {
      try Main.laborer.performIntegration(
        query: .init(cfg: configuration)
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
