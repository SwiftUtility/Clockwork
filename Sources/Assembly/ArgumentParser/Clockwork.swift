import ArgumentParser
import Foundation
import Facility
import FacilityPure
import InteractivityCommon
struct Clockwork: ParsableCommand {
  static var version: String { "0.1.0" }
  @Option(help: "The path to the profile")
  var profile = ".clockwork.yml"
  @Flag(help: "Should log subprocesses")
  var logsubs = false
  static let configuration = CommandConfiguration(
    abstract: "Distributed scalable monorepo management tool",
    version: Self.version,
    subcommands: [
      ReportCustom.self,
      CheckUnownedCode.self,
      CheckFileTaboos.self,
      CheckReviewConflictMarkers.self,
      CheckReviewObsolete.self,
      CheckForbiddenCommits.self,
      CheckResolutionRules.self,
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
      ExportIntegrationTargets.self,
      StartIntegration.self,
      FinishIntegration.self,
      ImportProvisions.self,
      ImportPkcs12.self,
      ImportRequisites.self,
      ReportExpiringRequisites.self,
      CreateDeployTag.self,
      CreateReleaseBranch.self,
      CreateHotfixBranch.self,
      CreateAccessoryBranch.self,
      ReserveParentReviewBuild.self,
      ReserveProtectedBuild.self,
      ExportBuildContext.self,
      ExportCurrentVersions.self,
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
  }
  struct CheckUnownedCode: ClockworkCommand {
    static var abstract: String { "Ensure no unowned files" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CheckFileTaboos: ClockworkCommand {
    static var abstract: String { "Ensure files match defined rules" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CheckReviewConflictMarkers: ClockworkCommand {
    static var abstract: String { "Ensure no conflict markers" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "the branch to diff with")
    var target: String
  }
  struct CheckReviewObsolete: ClockworkCommand {
    static var abstract: String { "Ensure target has no essential changes" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "the branch to check obsolence against")
    var target: String
  }
  struct CheckForbiddenCommits: ClockworkCommand {
    static var abstract: String { "Ensure contains no forbidden commits" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CheckResolutionRules: ClockworkCommand {
    static var abstract: String { "Ensure title matches defined rules" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CheckReviewStatus: ClockworkCommand {
    static var abstract: String { "Ensure review is ready to automatic merge" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CheckResolutionAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should remind present groups")
    var remind = false
  }
  struct AddReviewLabels: ClockworkCommand {
    static var abstract: String { "Add labels to triggerer review" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Labels to be added to triggerer review")
    var labels: [String]
  }
  struct ActivateAwardApprover: ClockworkCommand {
    static var abstract: String { "Set user status to active" }
    @OptionGroup var clockwork: Clockwork
  }
  struct DeactivateAwardApprover: ClockworkCommand {
    static var abstract: String { "Set user status to inactive" }
    @OptionGroup var clockwork: Clockwork
  }
  struct FinishResolution: ClockworkCommand {
    static var abstract: String { "Accept or update review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct TriggerPipeline: ClockworkCommand {
    static var abstract: String { "Trigger pipeline and pass predefined and custom context" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Ref to run pipeline on")
    var ref: String
    @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
    var context: [String] = []
  }
  struct CheckReplicationAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should remind present groups")
    var remind = false
  }
  struct StartReplication: ClockworkCommand {
    static var abstract: String { "Create replication review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct FinishReplication: ClockworkCommand {
    static var abstract: String { "Update or accept replication review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CheckIntegrationAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should remind present groups")
    var remind = false
  }
  struct ExportIntegrationTargets: ClockworkCommand {
    static var abstract: String { "Stdouts rendered suitable integration branches context" }
    @OptionGroup var clockwork: Clockwork
  }
  struct StartIntegration: ClockworkCommand {
    static var abstract: String { "Create current branch integration review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Integrated commit sha")
    var fork: String
    @Option(help: "Integration target branch name")
    var target: String
  }
  struct FinishIntegration: ClockworkCommand {
    static var abstract: String { "Accept or update integration review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ImportProvisions: ClockworkCommand {
    static var abstract: String { "Import provisions locally" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Requisites to install, all when empty (default)")
    var requisites: [String] = []
  }
  struct ImportPkcs12: ClockworkCommand {
    static var abstract: String { "Import p12 and setup xcode access" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Keychain name to import p12 into")
    var keychain: String
    @Argument(help: "Requisites to install, all when empty (default)")
    var requisites: [String] = []
  }
  struct ImportRequisites: ClockworkCommand {
    static var abstract: String { "Import p12 and provisions" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Keychain name to import p12 into")
    var keychain: String
    @Argument(help: "Requisite to install, all when empty (default)")
    var requisites: [String] = []
  }
  struct ReportExpiringRequisites: ClockworkCommand {
    static var abstract: String { "Report expiring provisions and certificates" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Days till expired threashold 0 (default) = already expired")
    var days: UInt = 0
  }
  struct CreateDeployTag: ClockworkCommand {
    static var abstract: String { "Create deploy tag with next build number on release branch" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CreateReleaseBranch: ClockworkCommand {
    static var abstract: String { "Cut release branch and bump current product version" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Product name to make branch for")
    var product: String
  }
  struct CreateHotfixBranch: ClockworkCommand {
    static var abstract: String { "Cut hotfix branch from deploy tag" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CreateAccessoryBranch: ClockworkCommand {
    static var abstract: String { "Cut custom branch" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Name suffix of branch")
    var suffix: String
  }
  struct ReserveParentReviewBuild: ClockworkCommand {
    static var abstract: String { "Reserves build number for parent review pipeline" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ReserveProtectedBuild: ClockworkCommand {
    static var abstract: String { "Reserves build number for current protected branch pipeline" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ExportBuildContext: ClockworkCommand {
    static var abstract: String { "Renders reserved build and versions to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ExportCurrentVersions: ClockworkCommand {
    static var abstract: String { "Renders current next versions to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CreateReviewPipeline: ClockworkCommand {
    static var abstract: String { "Creates new pipeline for parent review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct PlayParentJob: ClockworkCommand {
    static var abstract: String { "Plays parent pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CancelParentJob: ClockworkCommand {
    static var abstract: String { "Cancels parent pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
  }
  struct RetryParentJob: ClockworkCommand {
    static var abstract: String { "Retries parent pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
  }
  struct PlayNeighborJob: ClockworkCommand {
    static var abstract: String { "Plays current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to paly")
    var name: String
  }
  struct CancelNeighborJob: ClockworkCommand {
    static var abstract: String { "Cancels current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to cancel")
    var name: String
  }
  struct RetryNeighborJob: ClockworkCommand {
    static var abstract: String { "Retries current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to retry")
    var name: String
  }
}
protocol ClockworkCommand: ParsableCommand {
  var clockwork: Clockwork { get }
  static var abstract: String { get }
}
extension ClockworkCommand {
  static var configuration: CommandConfiguration {
    .init(abstract: abstract)
  }
}
