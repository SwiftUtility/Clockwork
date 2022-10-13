import ArgumentParser
struct Clockwork: ParsableCommand {
  static var version: String { "0.4.0" }
  @Option(help: "The path to the profile")
  var profile = ".clockwork.yml"
  static let configuration = CommandConfiguration(
    abstract: "Distributed scalable monorepo management tool",
    version: Self.version,
    subcommands: [
      AcceptReview.self,
      AddReviewLabels.self,
      ApproveReview.self,
      CancelJobs.self,
      CheckConflictMarkers.self,
      CheckFileTaboos.self,
      CheckUnownedCode.self,
      CreateAccessoryBranch.self,
      CreateDeployTag.self,
      CreateHotfixBranch.self,
      CreateReleaseBranch.self,
      DequeueReview.self,
      EraseRequisites.self,
      ExportBuild.self,
      ExportIntegration.self,
      ExportNextVersions.self,
      ImportRequisites.self,
      ImportPkcs12.self,
      ImportProvisions.self,
      OwnReview.self,
      PlayJobs.self,
      RemindReviews.self,
      ReportCustom.self,
      ReportCustomRelease.self,
      ReportCustomReview.self,
      ReportExpiringRequisites.self,
      ReserveBranchBuild.self,
      ReserveReviewBuild.self,
      ResetPodSpecs.self,
      RetryJobs.self,
      RemoveReviewLabels.self,
      TriggerPipeline.self,
      TriggerReviewPipeline.self,
      StartReplication.self,
      StartIntegration.self,
      UpdatePodSpecs.self,
      UpdateApprover.self,
      UpdateReview.self,
    ]
  )
  struct AcceptReview: ClockworkCommand {
    static var abstract: String { "Accept parent review" }
    @OptionGroup var clockwork: Clockwork
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
    enum Resolution: EnumerableFlag {
      case block
      case fragil
      case advance
      static func help(for value: Self) -> ArgumentHelp? {
        switch value {
        case .block: return "Block review"
        case .fragil: return "Approve current commit only"
        case .advance: return "Approve review in advance"
        }
      }
    }
    @Flag(help: "Resolution for approval")
    var resolution: Resolution
  }
  struct CancelJobs: ClockworkCommand {
    static var abstract: String { "Cancel job" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Jobs pipeline id")
    var pipeline: String
    @Argument(help: "Job names to cancel")
    var names: [String]
  }
  struct CheckConflictMarkers: ClockworkCommand {
    static var abstract: String { "Ensure no conflict markers" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "The commit sha to diff with")
    var base: String
    @Flag(help: "Should render json to stdout")
    var json = false
  }
  struct CheckFileTaboos: ClockworkCommand {
    static var abstract: String { "Ensure files match defined rules" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should render json to stdout")
    var json = false
  }
  struct CheckUnownedCode: ClockworkCommand {
    static var abstract: String { "Ensure no unowned files" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Should render json to stdout")
    var json = false
  }
  struct CreateAccessoryBranch: ClockworkCommand {
    static var abstract: String { "Cut custom protected branch" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Name of the branch")
    var name: String
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
  struct DequeueReview: ClockworkCommand {
    static var abstract: String { "Dequeue parent review" }
    @OptionGroup var clockwork: Clockwork
  }
  struct EraseRequisites: ClockworkCommand {
    static var abstract: String { "Delete keychain and provisions" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ExportBuild: ClockworkCommand {
    static var abstract: String { "Render reserved build and versions to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ExportIntegration: ClockworkCommand {
    static var abstract: String { "Render integration suitable branches to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ExportNextVersions: ClockworkCommand {
    static var abstract: String { "Render current next versions to stdout" }
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
  struct OwnReview: ClockworkCommand {
    static var abstract: String { "Transmith authorship to user" }
    @OptionGroup var clockwork: Clockwork
  }
  struct PlayJobs: ClockworkCommand {
    static var abstract: String { "Play job with matching names" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Jobs pipeline id")
    var pipeline: String
    @Argument(help: "Job names to paly")
    var names: [String]
  }
  struct RemindReviews: ClockworkCommand {
    static var abstract: String { "Remind review approvers" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ReportCustom: ClockworkCommand {
    static var abstract: String { "Sends preconfigured report" }
    @OptionGroup var clockwork: Clockwork
    enum Stdin: EnumerableFlag {
      case ignore
      case lines
      case json
      static func help(for value: Self) -> ArgumentHelp? {
        switch value {
        case .ignore: return "Do not read stdin"
        case .lines: return "Interpret stdin as lines array context"
        case .json: return "Interpret stdin as json context"
        }
      }
    }
    @Flag(help: "Should read stdin and pass as a context for generation")
    var stdin: Stdin = .ignore
    @Option(help: "Event name to send report for")
    var event: String
  }
  struct ReportCustomRelease: ClockworkCommand {
    static var abstract: String { "Send preconfigured release report" }
    @OptionGroup var clockwork: Clockwork
    @OptionGroup var custom: ReportCustom
  }
  struct ReportCustomReview: ClockworkCommand {
    static var abstract: String { "Send preconfigured parent review report" }
    @OptionGroup var clockwork: Clockwork
    @OptionGroup var custom: ReportCustom
  }
  struct ReportExpiringRequisites: ClockworkCommand {
    static var abstract: String { "Report expiring provisions and certificates" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Days till expired threashold or 0")
    var days: UInt = 0
  }
  struct ReserveBranchBuild: ClockworkCommand {
    static var abstract: String { "Reserve build number for current protected branch pipeline" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ReserveReviewBuild: ClockworkCommand {
    static var abstract: String { "Reserve build number for parent review pipeline" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ResetPodSpecs: ClockworkCommand {
    static var abstract: String { "Reset cocoapods specs to configured commits" }
    @OptionGroup var clockwork: Clockwork
  }
  struct RetryJobs: ClockworkCommand {
    static var abstract: String { "Retry current pipeline's job with matching name" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Jobs pipeline id")
    var pipeline: String
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
  struct UpdatePodSpecs: ClockworkCommand {
    static var abstract: String { "Update cocoapods specs and configured commist" }
    @OptionGroup var clockwork: Clockwork
  }
  struct UpdateApprover: ClockworkCommand {
    static var abstract: String { "Update approver status" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "Is approver active")
    var active = true
    @Option(help: "Approver slack id or current")
    var slack: String = ""
    @Option(help: "Approver gitlab login or current")
    var gitlab: String = ""
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
