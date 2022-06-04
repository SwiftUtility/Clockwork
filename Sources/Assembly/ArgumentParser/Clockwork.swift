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
      UpdateGitlabReplication.self,
      RenderGitlabIntegration.self,
      StartGitlabIntegration.self,
      FinishGitlabIntegration.self,
      InstallProvisions.self,
      InstallKeychains.self,
      InstallRequisites.self,
      ReportExpiringRequisites.self,
      CreateDeployTag.self,
      CreateReleaseBranch.self,
      CreateHotfixBranch.self,
      ReserveBuildNumber.self,
      RenderVersions.self,
      ReportReleaseNotes.self,
    ]
  )
  struct CheckUnownedCode: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Ensure no unowned files" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateUnownedCode(cfg: cfg)
    }
  }
  struct CheckFileRules: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Ensure files match defined rules" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateFileRules(cfg: cfg)
    }
  }
  struct CheckReviewConflictMarkers: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "the branch to diff with")
    var target: String
    static var abstract: String { "Ensure no conflict markers" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewConflictMarkers(cfg: cfg, target: target)
    }
  }
  struct CheckReviewObsolete: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "the branch to check obsolence against")
    var target: String
    static var abstract: String { "Ensure source is in sync with target" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewObsolete(cfg: cfg, target: target)
    }
  }
  struct CheckReviewTitle: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Title to be validated")
    var title: String
    static var abstract: String { "Ensure title matches defined rules" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewTitle(cfg: cfg, title: title)
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
  struct RenderGitlabIntegration: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Stdouts rendered job template for suitable branches" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.renderIntegration(cfg: cfg)
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
  struct InstallProvisions: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Groups to install, all when empty")
    var requisites: [String] = []
    static var abstract: String { "Import provisions locally" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.installProvisions(cfg: cfg, requisites: requisites)
    }
  }
  struct InstallKeychains: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Groups to install, all when empty")
    var requisites: [String] = []
    static var abstract: String { "Import p12 and setup xcode access" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.installKeychains(cfg: cfg, requisites: requisites)
    }
  }
  struct InstallRequisites: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Groups to install, all when empty")
    var requisites: [String] = []
    static var abstract: String { "Import p12 and provisions" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.installRequisites(cfg: cfg, requisites: requisites)
    }
  }
  struct ReportExpiringRequisites: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Days till expired threashold 0 (default) = already expired")
    var days: UInt = 0
    static var abstract: String { "Report expiring provisions and certificates" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.reportExpiringRequisites(cfg: cfg, days: days)
    }
  }
  struct CreateDeployTag: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Create deploy tag with next build number on release branch" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.createDeployTag(cfg: cfg)
    }
  }
  struct CreateReleaseBranch: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Product name to make branch for")
    var product: String
    static var abstract: String { "Cut release branch and bump current product version" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.createReleaseBranch(cfg: cfg, product: product)
    }
  }
  struct CreateHotfixBranch: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Cut release branch from deploy tag" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.createHotfixBranch(cfg: cfg)
    }
  }
  struct ReserveBuildNumber: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Reserves build number for parent pipeline" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.reserveBuildNumber(cfg: cfg)
    }
  }
  struct RenderVersions: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Resolves build and/or versions and renders to stdout" }
    @Option(help: "Local template name to use for rendering")
    var template: String
    @Flag(help: "Should resolve build number")
    var build: Bool = false
    @Argument(help: "Current branch name")
    var branch: String = ""
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.renderVersions(
        cfg: cfg,
        template: template,
        build: build,
        branch: branch
      )
    }
  }
  struct ReportReleaseNotes: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { """
    Produce and report notes of commits between HEAD and tag
    If no tag provided look for most recent or previous release tag to diff against
    """}
    @Argument(help: "Tag to diff with")
    var tag: String = ""
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.reportReleaseNotes(cfg: cfg, tag: tag)
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
