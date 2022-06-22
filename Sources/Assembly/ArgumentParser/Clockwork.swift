import ArgumentParser
import Foundation
import Facility
import FacilityPure
import InteractivityCommon
struct Clockwork: ParsableCommand {
  @Option(help: "The path to the profile")
  var profile = ".clockwork.yml"
  @Flag(help: "Should log subprocesses")
  var logsubs = false
  static let configuration = CommandConfiguration(
    abstract: "Distributed scalable monorepo management tool",
    version: Main.version,
    subcommands: [
      ReportCustom.self,
      CheckUnownedCode.self,
      CheckFileTaboos.self,
      CheckReviewConflictMarkers.self,
      CheckReviewObsolete.self,
      CheckReviewTitle.self,
      CheckReviewStatus.self,
      CheckGitlabReviewAwardApproval.self,
      CheckGitlabReplicationAwardApproval.self,
      CheckGitlabIntegrationAwardApproval.self,
      AddGitlabReviewLabels.self,
      ActivateGitlabApprover.self,
      DeactivateGitlabApprover.self,
      AcceptGitlabReview.self,
      TriggerGitlabPipeline.self,
      StartGitlabReplication.self,
      UpdateGitlabReplication.self,
      RenderGitlabIntegration.self,
      StartGitlabIntegration.self,
      FinishGitlabIntegration.self,
      ImportProvisions.self,
      ImportKeychain.self,
      ImportRequisites.self,
      ReportExpiringRequisites.self,
      CreateGitlabDeployTag.self,
      CreateGitlabCustomDeployTag.self,
      CreateGitlabReleaseBranch.self,
      CreateGitlabHotfixBranch.self,
      ReserveGitlabBuildNumber.self,
      RenderProtectedBuild.self,
      RenderReviewBuild.self,
      RenderVersions.self,
      ReportReleaseNotes.self,
      CreateReviewPipeline.self,
    ]
  )
  struct ReportCustom: ClockworkCommand {
    static var abstract: String { "Sends preconfigured report" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should read stdin")
    var stdin = false
    @Argument(help: "Event name to send report for")
    var event: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.reporter.reportCustom(cfg: cfg, event: event, stdin: stdin)
    }
  }
  struct CheckUnownedCode: ClockworkCommand {
    static var abstract: String { "Ensure no unowned files" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateUnownedCode(cfg: cfg)
    }
  }
  struct CheckFileTaboos: ClockworkCommand {
    static var abstract: String { "Ensure files match defined rules" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateFileTaboos(cfg: cfg)
    }
  }
  struct CheckReviewConflictMarkers: ClockworkCommand {
    static var abstract: String { "Ensure no conflict markers" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "the branch to diff with")
    var target: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewConflictMarkers(cfg: cfg, target: target)
    }
  }
  struct CheckReviewObsolete: ClockworkCommand {
    static var abstract: String { "Ensure source is in sync with target" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "the branch to check obsolence against")
    var target: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewObsolete(cfg: cfg, target: target)
    }
  }
  struct CheckReviewTitle: ClockworkCommand {
    static var abstract: String { "Ensure title matches defined rules" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Title to be validated")
    var title: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.validateReviewTitle(cfg: cfg, title: title)
    }
  }
  struct CheckReviewStatus: ClockworkCommand {
    static var abstract: String { "Ensure review is ready to automatic merge" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.validateReviewStatus(cfg: cfg)
    }
  }
  struct CheckGitlabReviewAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabAwardApprover.checkAwardApproval(cfg: cfg, mode: .review)
    }
  }
  struct AddGitlabReviewLabels: ClockworkCommand {
    static var abstract: String { "Add labels to triggerer review" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Labels to be added to triggerer review")
    var labels: [String]
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabCommunicatior.addReviewLabels(cfg: cfg, labels: labels)
    }
  }
  struct ActivateGitlabApprover: ClockworkCommand {
    static var abstract: String { "Set user status to active" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabAwardApprover.updateUser(cfg: cfg, active: true)
    }
  }
  struct DeactivateGitlabApprover: ClockworkCommand {
    static var abstract: String { "Set user status to inactive" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabAwardApprover.updateUser(cfg: cfg, active: false)
    }
  }
  struct AcceptGitlabReview: ClockworkCommand {
    static var abstract: String { "Rebase and accept review" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.acceptReview(cfg: cfg)
    }
  }
  struct TriggerGitlabPipeline: ClockworkCommand {
    static var abstract: String { "Trigger pipeline and pass context" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Ref to run pipeline on")
    var ref: String
    @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
    var context: [String] = []
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabCommunicatior.triggerTargetPipeline(
        cfg: cfg,
        ref: ref,
        context: context
      )
    }
  }
  struct CheckGitlabReplicationAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabAwardApprover.checkAwardApproval(cfg: cfg, mode: .replication)
    }
  }
  struct StartGitlabReplication: ClockworkCommand {
    static var abstract: String { "Create replication review" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.updateReplication(cfg: cfg)
    }
  }
  struct UpdateGitlabReplication: ClockworkCommand {
    static var abstract: String { "Update or accept replication review" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.updateReplication(cfg: cfg)
    }
  }
  struct CheckGitlabIntegrationAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabAwardApprover.checkAwardApproval(cfg: cfg, mode: .integration)
    }
  }
  struct RenderGitlabIntegration: ClockworkCommand {
    static var abstract: String { "Stdouts rendered job template for suitable branches" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Local template name to use for rendering")
    var template: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.renderIntegration(cfg: cfg, template: template)
    }
  }
  struct StartGitlabIntegration: ClockworkCommand {
    static var abstract: String { "Create integration review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Integration target branch")
    var target: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.startIntegration(cfg: cfg, target: target)
    }
  }
  struct FinishGitlabIntegration: ClockworkCommand {
    static var abstract: String { "Accept or update integration review" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabMerger.finishIntegration(cfg: cfg)
    }
  }
  struct ImportProvisions: ClockworkCommand {
    static var abstract: String { "Import provisions locally" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Requisite to install, all when empty")
    var requisite: String = ""
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.installProvisions(cfg: cfg, requisite: requisite)
    }
  }
  struct ImportKeychain: ClockworkCommand {
    static var abstract: String { "Import p12 and setup xcode access" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Keychain name to import requisites into")
    var keychain: String
    @Argument(help: "Requisite to install, all when empty")
    var requisite: String = ""
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.installKeychain(cfg: cfg, keychain: keychain, requisite: requisite)
    }
  }
  struct ImportRequisites: ClockworkCommand {
    static var abstract: String { "Import p12 and provisions" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Keychain name to import requisites into")
    var keychain: String
    @Argument(help: "Requisite to install, all when empty")
    var requisite: String = ""
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.installRequisite(cfg: cfg, keychain: keychain, requisite: requisite)
    }
  }
  struct ReportExpiringRequisites: ClockworkCommand {
    static var abstract: String { "Report expiring provisions and certificates" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Days till expired threashold 0 (default) = already expired")
    var days: UInt = 0
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.reportExpiringRequisites(cfg: cfg, days: days)
    }
  }
  struct CreateGitlabDeployTag: ClockworkCommand {
    static var abstract: String { "Create deploy tag with next build number on release branch" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.createDeployTag(cfg: cfg)
    }
  }
  struct CreateGitlabCustomDeployTag: ClockworkCommand {
    static var abstract: String { "Create deploy tag with next build number on any protected ref" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Product to deploy")
    var product: String
    @Option(help: "Version to deploy")
    var version: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.createCustomDeployTag(
        cfg: cfg,
        product: product,
        version: version
      )
    }
  }
  struct CreateGitlabReleaseBranch: ClockworkCommand {
    static var abstract: String { "Cut release branch and bump current product version" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Product name to make branch for")
    var product: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.createReleaseBranch(cfg: cfg, product: product)
    }
  }
  struct CreateGitlabHotfixBranch: ClockworkCommand {
    static var abstract: String { "Cut release branch from deploy tag" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.createHotfixBranch(cfg: cfg)
    }
  }
  struct ReserveGitlabBuildNumber: ClockworkCommand {
    static var abstract: String { "Reserves build number for parent review pipeline" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.reserveReviewBuild(cfg: cfg)
    }
  }
  struct RenderProtectedBuild: ClockworkCommand {
    static var abstract: String { "Resolves or creates build and versions and renders to stdout" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Local template name to use for rendering")
    var template: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.renderProtectedBuild(cfg: cfg, template: template)
    }
  }
  struct RenderReviewBuild: ClockworkCommand {
    static var abstract: String {
      "Resolves reserved review build and versions and renders to stdout"
    }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Local template name to use for rendering")
    var template: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.renderReviewBuild(cfg: cfg, template: template)
    }
  }
  struct RenderVersions: ClockworkCommand {
    static var abstract: String { "Resolves versions and renders to stdout" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Local template name to use for rendering")
    var template: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.renderVersions(cfg: cfg, template: template)
    }
  }
  struct RenderCustom: ClockworkCommand {
    static var abstract: String { "Renders custom context to stdout" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Local yaml to be used in template")
    var yaml: String = ""
    @Argument(help: "Local template name to use for rendering")
    var template: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.configurator.renderCustom(cfg: cfg, yaml: yaml, template: template)
    }
  }
  struct ReportReleaseNotes: ClockworkCommand {
    static var abstract: String {
      "Produce and report notes of commits between HEAD tag and provided tag"
    }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Tag to diff with")
    var tag: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabVersionController.reportReleaseNotes(cfg: cfg, tag: tag)
    }
  }
  struct CreateReviewPipeline: ClockworkCommand {
    @OptionGroup var clockwork: Clockwork
    static var abstract: String { "Creates new pipeline for parent review" }
    func run(cfg: Configuration) throws -> Bool {
      try Main.gitlabCommunicatior.createReviewPipeline(cfg: cfg)
    }
  }
}
protocol ClockworkCommand: ParsableCommand {
  var clockwork: Clockwork { get }
  static var abstract: String { get }
  func run(cfg: Configuration) throws -> Bool
}
extension ClockworkCommand {
  static var configuration: CommandConfiguration {
    .init(abstract: abstract)
  }
  mutating func run() throws {
    let cfg = try Main.configurator.configure(
      profile: clockwork.profile,
      verbose: clockwork.logsubs,
      env: Main.environment
    )
    try Lossy(cfg)
      .map(run(cfg:))
      .reduceError(cfg, Main.reporter.report(cfg:error:))
      .reduce(cfg, Main.reporter.finish(cfg:success:))
      .get()
  }
}
