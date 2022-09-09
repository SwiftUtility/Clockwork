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
      AcceptReview.self,
      ActivateApprover.self,
      AddReviewLabels.self,
      ApproveReview.self,
      CancelJobs.self,
      CheckConflictMarkers.self,
      CheckFileTaboos.self,
      CheckForbiddenCommits.self,
      CheckReviewObsolete.self,
      CheckUnownedCode.self,
      CreateAccessoryBranch.self,
      CreateDeployTag.self,
      CreateHotfixBranch.self,
      CreateReleaseBranch.self,
      DeactivateApprover.self,
      DequeueReview.self,
      EnqueueReview.self,
      EraseRequisites.self,
      ExportBuildContext.self,
      ExportCurrentVersions.self,
      ExportIntegrationTargets.self,
      HoldReview.self,
      ImportRequisites.self,
      ImportPkcs12.self,
      ImportProvisions.self,
      PlayJobs.self,
      ReportCustom.self,
      ReportCustomReview.self,
      ReportCustomRelease.self,
      ReportExpiringRequisites.self,
      ReserveParentReviewBuild.self,
      ReserveProtectedBuild.self,
      ResetPodSpecs.self,
      RetryJobs.self,
      RemoveReviewLabels.self,
      TriggerPipeline.self,
      TriggerReviewPipeline.self,
      StartReplication.self,
      StartIntegration.self,
      UnholdReview.self,
      UpdatePodSpecs.self,
      UpdateReview.self,
    ]
  )
  struct AcceptReview: ClockworkCommand {
    static var abstract: String { "Accept parent review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ActivateApprover: ClockworkCommand {
    static var abstract: String { "Change approver status to active" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "User login to be activated or current")
    var login: String = ""
  }
  struct AddReviewLabels: ClockworkCommand {
    static var abstract: String { "Add labels to parent review" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Labels to be added to parent review")
    var labels: [String]
  }
  struct ApproveReview: ClockworkCommand {
    static var abstract: String { "Approve parent review" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Teams to approve")
    var teams: [String]
  }
  struct CancelJobs: ClockworkCommand {
    static var abstract: String { "Cancel job" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Id of jobs pipeline or current")
    var pipeline: String = ""
    @Argument(help: "Job names to cancel")
    var names: [String]
  }
  struct CheckConflictMarkers: ClockworkCommand {
    static var abstract: String { "Ensure no conflict markers" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "The branch to diff with")
    var target: String
  }
  struct CheckFileTaboos: ClockworkCommand {
    static var abstract: String { "Ensure files match defined rules" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CheckForbiddenCommits: ClockworkCommand {
    static var abstract: String { "Ensure contains no forbidden commits" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CheckReviewObsolete: ClockworkCommand {
    static var abstract: String { "Ensure review target has no essential changes" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "the branch to check obsolence against")
    var target: String
  }
  struct CheckUnownedCode: ClockworkCommand {
    static var abstract: String { "Ensure no unowned files" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CreateAccessoryBranch: ClockworkCommand {
    static var abstract: String { "Cut custom protected branch" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Name suffix of branch")
    var suffix: String
  }
  struct CreateDeployTag: ClockworkCommand {
    static var abstract: String { "Create deploy tag on release branch" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CreateHotfixBranch: ClockworkCommand {
    static var abstract: String { "Cut hotfix branch from deploy tag" }
    @OptionGroup var clockwork: Clockwork
  }
  struct CreateReleaseBranch: ClockworkCommand {
    static var abstract: String { "Cut release branch and bump product version" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Product name to make branch for")
    var product: String
  }
  struct DeactivateApprover: ClockworkCommand {
    static var abstract: String { "Set user status to inactive" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "User login to be deactivated or current")
    var login: String = ""
  }
  struct DequeueReview: ClockworkCommand {
    static var abstract: String { "Dequeue parent review and trigger pipeline for new leaders" }
    @OptionGroup var clockwork: Clockwork
  }
  struct EnqueueReview: ClockworkCommand {
    static var abstract: String { "Enqueue parent review and trigger pipeline for new leaders" }
    @OptionGroup var clockwork: Clockwork
  }
  struct EraseRequisites: ClockworkCommand {
    static var abstract: String { "Delete keychain and provisions" }
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
  struct ExportIntegrationTargets: ClockworkCommand {
    static var abstract: String { "Render integration suitable branches to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct HoldReview: ClockworkCommand {
    static var abstract: String { "Prevent parent review merge by active users" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ImportRequisites: ClockworkCommand {
    static var abstract: String { "Import p12 and provisions" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Requisite to install or all")
    var requisites: [String] = []
  }
  struct ImportPkcs12: ClockworkCommand {
    static var abstract: String { "Import p12" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Requisites to install or all")
    var requisites: [String] = []
  }
  struct ImportProvisions: ClockworkCommand {
    static var abstract: String { "Import provisions" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Requisites to install or all")
    var requisites: [String] = []
  }
  struct PlayJobs: ClockworkCommand {
    static var abstract: String { "Play job with matching names" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Id of jobs pipeline or current")
    var pipeline: String = ""
    @Argument(help: "Job names to paly")
    var names: [String]
  }
  struct ReportCustom: ClockworkCommand {
    static var abstract: String { "Sends preconfigured report" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should read stdin")
    var stdin = false
    @Option(help: "Event name to send report for")
    var event: String
  }
  struct ReportCustomReview: ClockworkCommand {
    static var abstract: String { "Send preconfigured parent review report" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should read stdin")
    var stdin = false
    @Option(help: "Event name to send report for")
    var event: String
  }
  struct ReportCustomRelease: ClockworkCommand {
    static var abstract: String { "Send preconfigured release report" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should read stdin")
    var stdin = false
    @Option(help: "Event name to send report for")
    var event: String
  }
  struct ReportExpiringRequisites: ClockworkCommand {
    static var abstract: String { "Report expiring provisions and certificates" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Days till expired threashold or 0")
    var days: UInt = 0
  }
  struct ReserveParentReviewBuild: ClockworkCommand {
    static var abstract: String { "Reserve build number for parent review pipeline" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ReserveProtectedBuild: ClockworkCommand {
    static var abstract: String { "Reserve build number for current protected branch pipeline" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ResetPodSpecs: ClockworkCommand {
    static var abstract: String { "Reset cocoapods specs to configured commits" }
    @OptionGroup var clockwork: Clockwork
  }
  struct RetryJobs: ClockworkCommand {
    static var abstract: String { "Retry current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Id of jobs pipeline or current")
    var pipeline: String = ""
    @Argument(help: "Job names to retry")
    var names: [String]
  }
  struct RemoveReviewLabels: ClockworkCommand {
    static var abstract: String { "Remove parent review labels" }
    @OptionGroup var clockwork: Clockwork
    @Argument(help: "Labels to be removed from parent review")
    var labels: [String]
  }
  struct TriggerPipeline: ClockworkCommand {
    static var abstract: String { "Trigger pipeline configured and custom context" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Ref to run pipeline on")
    var ref: String
    @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
    var context: [String] = []
  }
  struct TriggerReviewPipeline: ClockworkCommand {
    static var abstract: String { "Create new pipeline for parent review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct StartReplication: ClockworkCommand {
    static var abstract: String { "Create replication review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct StartIntegration: ClockworkCommand {
    static var abstract: String { "Create integration review" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Integrated commit sha")
    var fork: String
    @Option(help: "Integration target branch name")
    var target: String
    @Option(help: "Integration source branch name")
    var source: String
  }
  struct UnholdReview: ClockworkCommand {
    static var abstract: String { "Allow parent review merge by active users" }
    @OptionGroup var clockwork: Clockwork
  }
  struct UpdatePodSpecs: ClockworkCommand {
    static var abstract: String { "Update cocoapods specs and configured commist" }
    @OptionGroup var clockwork: Clockwork
  }
  struct UpdateReview: ClockworkCommand {
    static var abstract: String { "Update parent review state" }
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
