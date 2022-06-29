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
      CheckForbiddenCommits.self,
      CheckResolutionTitle.self,
      CheckReviewStatus.self,
      CheckResolutionAwardApproval.self,
      CheckReplicationAwardApproval.self,
      CheckIntegrationAwardApproval.self,
      AddReviewLabels.self,
      ActivateAwardApprover.self,
      DeactivateAwardApprover.self,
      FinishResolution.self,
      TriggerPipeline.self,
      StartReplication.self,
      FinishReplication.self,
      RenderIntegration.self,
      StartIntegration.self,
      FinishIntegration.self,
      ImportProvisions.self,
      ImportKeychain.self,
      ImportRequisites.self,
      ReportExpiringRequisites.self,
      CreateDeployTag.self,
      CreateReleaseBranch.self,
      CreateHotfixBranch.self,
      CreateAccessoryBranch.self,
      ReserveParentReviewBuild.self,
      ReserveProtectedBuild.self,
      RenderBuild.self,
      RenderVersions.self,
      CreateReviewPipeline.self,
      PlayParentJob.self,
      CancelParentJob.self,
      RetryParentJob.self,
      PlayNeighborJob.self,
      CancelNeighborJob.self,
      RetryNeighborJob.self,
    ]
  )
  struct ReportCustom: ClockworkCommand {
    static var abstract: String { "Sends preconfigured report" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should read stdin")
    var stdin = false
    @Option(help: "Event name to send report for")
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
    @Option(help: "the branch to diff with")
    var target: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewConflictMarkers(cfg: cfg, target: target)
    }
  }
  struct CheckReviewObsolete: ClockworkCommand {
    static var abstract: String { "Ensure source is in sync with target" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "the branch to check obsolence against")
    var target: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateReviewObsolete(cfg: cfg, target: target)
    }
  }
  struct CheckForbiddenCommits: ClockworkCommand {
    static var abstract: String { "Ensure contains no forbidden commits" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.validator.validateForbiddenCommits(cfg: cfg)
    }
  }
  struct CheckResolutionTitle: ClockworkCommand {
    static var abstract: String { "Ensure title matches defined rules" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.blender.validateResolutionTitle(cfg: cfg)
    }
  }
  struct CheckReviewStatus: ClockworkCommand {
    static var abstract: String { "Ensure review is ready to automatic merge" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.blender.validateReviewStatus(cfg: cfg)
    }
  }
  struct CheckResolutionAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should remind present groups")
    var remind = false
    func run(cfg: Configuration) throws -> Bool {
      try Main.decorator.checkAwardApproval(cfg: cfg, mode: .resolution, remind: remind)
    }
  }
  struct AddReviewLabels: ClockworkCommand {
    static var abstract: String { "Add labels to triggerer review" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Labels to be added to triggerer review")
    var labels: [String]
    func run(cfg: Configuration) throws -> Bool {
      try Main.mediator.addReviewLabels(cfg: cfg, labels: labels)
    }
  }
  struct ActivateAwardApprover: ClockworkCommand {
    static var abstract: String { "Set user status to active" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.decorator.updateUser(cfg: cfg, active: true)
    }
  }
  struct DeactivateAwardApprover: ClockworkCommand {
    static var abstract: String { "Set user status to inactive" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.decorator.updateUser(cfg: cfg, active: false)
    }
  }
  struct FinishResolution: ClockworkCommand {
    static var abstract: String { "Rebase and accept review" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.blender.acceptResolution(cfg: cfg)
    }
  }
  struct TriggerPipeline: ClockworkCommand {
    static var abstract: String { "Trigger pipeline and pass context" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Ref to run pipeline on")
    var ref: String
    @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
    var context: [String] = []
    func run(cfg: Configuration) throws -> Bool {
      try Main.mediator.triggerPipeline(cfg: cfg, ref: ref, context: context)
    }
  }
  struct CheckReplicationAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should remind present groups")
    var remind = false
    func run(cfg: Configuration) throws -> Bool {
      try Main.decorator.checkAwardApproval(cfg: cfg, mode: .replication, remind: remind)
    }
  }
  struct StartReplication: ClockworkCommand {
    static var abstract: String { "Create replication review" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.blender.updateReplication(cfg: cfg)
    }
  }
  struct FinishReplication: ClockworkCommand {
    static var abstract: String { "Update or accept replication review" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.blender.updateReplication(cfg: cfg)
    }
  }
  struct CheckIntegrationAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should remind present groups")
    var remind = false
    func run(cfg: Configuration) throws -> Bool {
      try Main.decorator.checkAwardApproval(cfg: cfg, mode: .integration, remind: remind)
    }
  }
  struct RenderIntegration: ClockworkCommand {
    static var abstract: String { "Stdouts rendered job template for suitable branches" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.blender.renderIntegration(cfg: cfg)
    }
  }
  struct StartIntegration: ClockworkCommand {
    static var abstract: String { "Create integration review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Integrated commit sha")
    var fork: String
    @Option(help: "Integration target branch name")
    var target: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.blender.startIntegration(cfg: cfg, target: target, fork: fork)
    }
  }
  struct FinishIntegration: ClockworkCommand {
    static var abstract: String { "Accept or update integration review" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.blender.finishIntegration(cfg: cfg)
    }
  }
  struct ImportProvisions: ClockworkCommand {
    static var abstract: String { "Import provisions locally" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Requisites to install, all when empty")
    var requisites: [String] = []
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.installProvisions(cfg: cfg, requisites: requisites)
    }
  }
  struct ImportKeychain: ClockworkCommand {
    static var abstract: String { "Import p12 and setup xcode access" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Keychain name to import requisites into")
    var keychain: String
    @Argument(help: "Requisites to install, all when empty")
    var requisites: [String] = []
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.installKeychain(cfg: cfg, keychain: keychain, requisites: requisites)
    }
  }
  struct ImportRequisites: ClockworkCommand {
    static var abstract: String { "Import p12 and provisions" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Keychain name to import requisites into")
    var keychain: String
    @Argument(help: "Requisite to install, all when empty")
    var requisites: [String] = []
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.installRequisite(cfg: cfg, keychain: keychain, requisites: requisites)
    }
  }
  struct ReportExpiringRequisites: ClockworkCommand {
    static var abstract: String { "Report expiring provisions and certificates" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Days till expired threashold 0 (default) = already expired")
    var days: UInt = 0
    func run(cfg: Configuration) throws -> Bool {
      try Main.requisitor.reportExpiringRequisites(cfg: cfg, days: days)
    }
  }
  struct CreateDeployTag: ClockworkCommand {
    static var abstract: String { "Create deploy tag with next build number on release branch" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.producer.createDeployTag(cfg: cfg)
    }
  }
  struct CreateReleaseBranch: ClockworkCommand {
    static var abstract: String { "Cut release branch and bump current product version" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Product name to make branch for")
    var product: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.producer.createReleaseBranch(cfg: cfg, product: product)
    }
  }
  struct CreateHotfixBranch: ClockworkCommand {
    static var abstract: String { "Cut release branch from deploy tag" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.producer.createHotfixBranch(cfg: cfg)
    }
  }
  struct CreateAccessoryBranch: ClockworkCommand {
    static var abstract: String { "Cut custom branch" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Accessory branch configuration family")
    var family: String
    @Option(help: "Name of branch to create")
    var name: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.producer.createAccessoryBranch(cfg: cfg, family: family, name: name)
    }
  }
  struct ReserveParentReviewBuild: ClockworkCommand {
    static var abstract: String { "Reserves build number for parent review pipeline" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.producer.reserveProtectedBuild(cfg: cfg)
    }
  }
  struct ReserveProtectedBuild: ClockworkCommand {
    static var abstract: String { "Reserves build number for current protected branch pipeline" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.producer.reserveProtectedBuild(cfg: cfg)
    }
  }
  struct RenderBuild: ClockworkCommand {
    static var abstract: String { "Renders reserved build and versions to stdout" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.producer.renderBuild(cfg: cfg)
    }
  }
  struct RenderVersions: ClockworkCommand {
    static var abstract: String { "Renders current next versions to stdout" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.producer.renderVersions(cfg: cfg)
    }
  }
  struct CreateReviewPipeline: ClockworkCommand {
    static var abstract: String { "Creates new pipeline for parent review" }
    @OptionGroup var clockwork: Clockwork
    func run(cfg: Configuration) throws -> Bool {
      try Main.mediator.createReviewPipeline(cfg: cfg)
    }
  }
  struct PlayParentJob: ClockworkCommand {
    static var abstract: String { "Plays parent pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to paly")
    var name: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.mediator.affectParentJob(configuration: cfg, name: name, action: .play)
    }
  }
  struct CancelParentJob: ClockworkCommand {
    static var abstract: String { "Cancels parent pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to cancel")
    var name: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.mediator.affectParentJob(configuration: cfg, name: name, action: .cancel)
    }
  }
  struct RetryParentJob: ClockworkCommand {
    static var abstract: String { "Retries parent pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to retry")
    var name: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.mediator.affectParentJob(configuration: cfg, name: name, action: .retry)
    }
  }
  struct PlayNeighborJob: ClockworkCommand {
    static var abstract: String { "Plays current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to paly")
    var name: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.mediator.affectNeighborJob(configuration: cfg, name: name, action: .play)
    }
  }
  struct CancelNeighborJob: ClockworkCommand {
    static var abstract: String { "Cancels current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to cancel")
    var name: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.mediator.affectNeighborJob(configuration: cfg, name: name, action: .cancel)
    }
  }
  struct RetryNeighborJob: ClockworkCommand {
    static var abstract: String { "Retries current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to retry")
    var name: String
    func run(cfg: Configuration) throws -> Bool {
      try Main.mediator.affectNeighborJob(configuration: cfg, name: name, action: .retry)
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
