import ArgumentParser
import Foundation
import Facility
import FacilityPure
import InteractivityCommon
struct Clockwork: ParsableCommand {
  static var version: String { "0.4.0" }
  @Option(help: "The path to the profile")
  var profile = ".clockwork.yml"
  @Flag(help: "Should log subprocesses")
  var logsubs = false
  static let configuration = CommandConfiguration(
    abstract: "Distributed scalable monorepo management tool",
    version: Self.version,
    subcommands: [
      ReportCustom.self,
      ReportReviewCustom.self,
      CheckUnownedCode.self,
      CheckFileTaboos.self,
      CheckReviewConflictMarkers.self,
      CheckReviewObsolete.self,
      CheckForbiddenCommits.self,
      CheckResolutionAwardApproval.self,
      CheckReplicationAwardApproval.self,
      CheckIntegrationAwardApproval.self,
      ActivateAwardApprover.self,
      DeactivateAwardApprover.self,
      AddReviewLabels.self,
      RemoveReviewLabels.self,
      TriggerPipeline.self,
      StartReplication.self,
      ExportIntegrationTargets.self,
      StartIntegration.self,
      UpdateReview.self,
      AcceptReview.self,
      ImportProvisions.self,
      ImportPkcs12.self,
      ImportRequisites.self,
      EraseRequisites.self,
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
      ResetPodSpecs.self,
      UpdatePodSpecs.self,
      EnqueueReview.self,
      DequeueReview.self,
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
  struct ReportReviewCustom: ClockworkCommand {
    static var abstract: String { "Send preconfigured parent review report" }
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
    static var abstract: String { "Ensure review target has no essential changes" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "the branch to check obsolence against")
    var target: String
  }
  struct CheckForbiddenCommits: ClockworkCommand {
    static var abstract: String { "Ensure contains no forbidden commits" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CheckResolutionAwardApproval: ClockworkCommand {
    static var abstract: String { "Check approval state and report new involved" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should remind present groups")
    var remind = false
  }
  struct AddReviewLabels: ClockworkCommand {
    static var abstract: String { "Add parent review labels" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Labels to be added to parent review")
    var labels: [String]
  }
  struct RemoveReviewLabels: ClockworkCommand {
    static var abstract: String { "Remove parent review labels" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Labels to be added to parent review")
    var labels: [String]
  }
  struct ActivateAwardApprover: ClockworkCommand {
    static var abstract: String { "Set user status to active" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "User login to be activated")
    var login: String = ""
  }
  struct DeactivateAwardApprover: ClockworkCommand {
    static var abstract: String { "Set user status to inactive" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "User login to be deactivated")
    var login: String = ""
  }
  struct AcceptReview: ClockworkCommand {
    static var abstract: String { "Accept review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct TriggerPipeline: ClockworkCommand {
    static var abstract: String { "Trigger pipeline configured and custom context" }
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
  struct UpdateReview: ClockworkCommand {
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
    static var abstract: String { "Render integration suitable branches to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct StartIntegration: ClockworkCommand {
    static var abstract: String { "Create current branch integration review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Integrated commit sha")
    var fork: String
    @Option(help: "Integration target branch name")
    var target: String
    @Option(help: "Integration source branch name")
    var source: String
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
    @Argument(help: "Requisites to install, all when empty (default)")
    var requisites: [String] = []
  }
  struct ImportRequisites: ClockworkCommand {
    static var abstract: String { "Import p12 and provisions" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Requisite to install, all when empty (default)")
    var requisites: [String] = []
  }
  struct EraseRequisites: ClockworkCommand {
    static var abstract: String { "Delete keychain and provisions" }
    @OptionGroup var clockwork: Clockwork
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
    static var abstract: String { "Cut custom branch from protected ref" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Name suffix of branch")
    var suffix: String
  }
  struct ReserveParentReviewBuild: ClockworkCommand {
    static var abstract: String { "Reserve build number for parent review pipeline" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ReserveProtectedBuild: ClockworkCommand {
    static var abstract: String { "Reserve build number for current protected branch pipeline" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ExportBuildContext: ClockworkCommand {
    static var abstract: String { "Render reserved build and versions to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ExportCurrentVersions: ClockworkCommand {
    static var abstract: String { "Render current next versions to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CreateReviewPipeline: ClockworkCommand {
    static var abstract: String { "Create new pipeline for parent review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct PlayParentJob: ClockworkCommand {
    static var abstract: String { "Play parent pipeline's job" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CancelParentJob: ClockworkCommand {
    static var abstract: String { "Cancel parent pipeline's job" }
    @OptionGroup var clockwork: Clockwork
  }
  struct RetryParentJob: ClockworkCommand {
    static var abstract: String { "Retry parent pipeline's job" }
    @OptionGroup var clockwork: Clockwork
  }
  struct PlayNeighborJob: ClockworkCommand {
    static var abstract: String { "Play current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to paly")
    var name: String
  }
  struct CancelNeighborJob: ClockworkCommand {
    static var abstract: String { "Cancel current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to cancel")
    var name: String
  }
  struct RetryNeighborJob: ClockworkCommand {
    static var abstract: String { "Retry current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Job name to retry")
    var name: String
  }
  struct ResetPodSpecs: ClockworkCommand {
    static var abstract: String { "Reset cocoapods specs to configured commits" }
    @OptionGroup var clockwork: Clockwork
  }
  struct UpdatePodSpecs: ClockworkCommand {
    static var abstract: String { "Update cocoapods specs and configured commist" }
    @OptionGroup var clockwork: Clockwork
  }
  struct EnqueueReview: ClockworkCommand {
    static var abstract: String { "Enqueue parent review and trigger others" }
    @OptionGroup var clockwork: Clockwork
  }
  struct DequeueReview: ClockworkCommand {
    static var abstract: String { "Dequeue parent review and trigger others" }
    @OptionGroup var clockwork: Clockwork
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
