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
  static let cfg = CommandConfiguration(
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
      UpdateGitlabReplication.self,
      GenerateGitlabIntegration.self,
      StartGitlabIntegration.self,
      FinishGitlabIntegration.self,
    ]
  )
  struct CheckUnownedCode: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Ensure no unowned files" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateUnownedCode(
        query: .init(cfg: cfg)
      )
    }
  }
  struct CheckFileRules: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Ensure files match defined rules" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateFileRules(
        query: .init(cfg: cfg)
      )
    }
  }
  struct CheckReviewConflictMarkers: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "the branch to diff with")
    var target: String
    static var abstract: String { "Ensure no conflict markers" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewConflictMarkers(
        query: .init(cfg: cfg, target: target)
      )
    }
  }
  struct CheckReviewObsolete: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "the branch to check obsolence against")
    var target: String
    static var abstract: String { "Ensure source is in sync with target" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewObsolete(
        query: .init(cfg: cfg, target: target)
      )
    }
  }
  struct CheckReviewTitle: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Title to be validated")
    var title: String
    static var abstract: String { "Ensure title matches defined rules" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewTitle(
        query: .init(cfg: cfg, title: title)
      )
    }
  }
  struct CheckGitlabReviewAwardApproval: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Check approval state and report new involved" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabAwardApprover.checkAwardApproval(cfg: cfg, mode: .review)
    }
  }
  struct AddGitlabReviewLabels: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Labels to be added to triggerer review")
    var labels: [String]
    static var abstract: String { "Add labels to triggerer review" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabCommunicatior.addReviewLabels(cfg: cfg, labels: labels)
    }
  }
  struct AcceptGitlabReview: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Rebase and accept review" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.acceptReview(cfg: cfg)
    }
  }
  struct TriggerGitlabPipeline: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Ref to run pipeline on")
    var ref: String
    @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
    var context: [String] = []
    static var abstract: String { "Trigger pipeline and pass context" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabCommunicatior.triggerTargetPipeline(
        cfg: cfg,
        ref: ref,
        context: context
      )
    }
  }
  struct CheckGitlabReplicationAwardApproval: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Check approval state and report new involved" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabAwardApprover.checkAwardApproval(cfg: cfg, mode: .replication)
    }
  }
  struct StartGitlabReplication: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Create replication review" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.updateReplication(cfg: cfg)
    }
  }
  struct UpdateGitlabReplication: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Update or accept replication review" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.updateReplication(cfg: cfg)
    }
  }
  struct CheckGitlabIntegrationAwardApproval: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Check approval state and report new involved" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabAwardApprover.checkAwardApproval(cfg: cfg, mode: .integration)
    }
  }
  struct GenerateGitlabIntegration: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Stdouts rendered job template for suitable branches" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.generateIntegration(cfg: cfg)
    }
  }
  struct StartGitlabIntegration: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Integration target branch")
    var target: String
    static var abstract: String { "Create integration review" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.startIntegration(cfg: cfg, target: target)
    }
  }
  struct FinishGitlabIntegration: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Accept or update integration review" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.finishIntegration(cfg: cfg)
    }
  }
}
protocol ClockworkCommand: ParsableCommand {
  var clockwork: Clockwork { get }
  static var abstract: String { get }
  func run(cfg: Configuration) throws -> Bool
}
extension ClockworkCommand {
  static var cfg: CommandConfiguration {
    .init(abstract: abstract)
  }
  mutating func run() throws {
    let cfg = try Main.configurator.resolveConfiguration(query: .init(
      profile: clockwork.profile,
      verbose: clockwork.verbose,
      env: Main.environment
    ))
    try Lossy(cfg)
      .map(run(cfg:))
      .reduceError(cfg, Main.reporter.report(cfg:error:))
      .reduce(cfg, Main.reporter.finish(cfg:success:))
      .get()
  }
}
