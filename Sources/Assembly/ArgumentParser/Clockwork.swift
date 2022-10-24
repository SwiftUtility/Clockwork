import ArgumentParser
struct Clockwork: ParsableCommand {
  static var version: String { "0.4.0" }
  @Option(help: "The path to the profile")
  var profile = ".clockwork.yml"
  static let configuration = CommandConfiguration(
    abstract: "Distributed scalable monorepo git flow management tool",
    version: Self.version,
    subcommands: [
      Approver.self,
      CancelJobs.self,
      CheckConflictMarkers.self,
      CheckFileTaboos.self,
      CheckUnownedCode.self,
      ChangeVersion.self,
      CreateAccessoryBranch.self,
      CreateDeployTag.self,
      CreateHotfixBranch.self,
      CreateReleaseBranch.self,
      CreateStageTag.self,
      DeleteAccessoryBranch.self,
      DeleteReleaseBranch.self,
      DeleteStageTag.self,
      ExportBuild.self,
      ExportNextVersions.self,
      ForwardBranch.self,
      PlayJobs.self,
      ReportCustom.self,
      ReportCustomRelease.self,
      Requisites.self,
      ReserveBranchBuild.self,
      ResetPodSpecs.self,
      RetryJobs.self,
      Review.self,
      TriggerPipeline.self,
      UpdatePodSpecs.self,
    ]
  )
  struct Approver: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Subset of approver manipulations commands",
      subcommands: [
        Activate.self,
        Deactivate.self,
        Register.self,
        UnwatchAuthors.self,
        UnwatchTeams.self,
        WatchAuthors.self,
        WatchTeams.self,
      ]
    )
    @Option(help: "Approver gitlab login or current")
    var gitlab: String = ""
    @Argument(help: "List of arguments required by subcommands")
    var args: [String] = []
    struct Activate: ClockworkCommand {
      static var abstract: String { "Activate user" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var approver: Approver
    }
    struct Deactivate: ClockworkCommand {
      static var abstract: String { "Deactivate user" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var approver: Approver
    }
    struct Register: ClockworkCommand {
      static var abstract: String { "Add new user" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var approver: Approver
      @Option(help: "Approver's slack id")
      var slack: String
    }
    struct UnwatchAuthors: ClockworkCommand {
      static var abstract: String { "Remove user from watchers for authors provided in arguments" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var approver: Approver
    }
    struct UnwatchTeams: ClockworkCommand {
      static var abstract: String { "Remove user from watchers for teams provided in arguments" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var approver: Approver
    }
    struct WatchAuthors: ClockworkCommand {
      static var abstract: String { "Add user to watchers for authors provided in arguments" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var approver: Approver
    }
    struct WatchTeams: ClockworkCommand {
      static var abstract: String { "Add user to watchers for teams provided in arguments" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var approver: Approver
    }
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
  struct ChangeVersion: ClockworkCommand {
    static var abstract: String { "Cut custom protected branch" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Product name to change version for")
    var product: String
    @Flag(help: "Wether change next or current accessory branch specific version")
    var next: Bool = false
    @Option(help: "Version to set")
    var version: String
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
  struct CreateStageTag: ClockworkCommand {
    static var abstract: String { "Create stage tag on reserved build" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Product name to make stage tag for")
    var product: String
    @Option(help: "Build number to make stage tag for")
    var build: String
  }
  struct DeleteAccessoryBranch: ClockworkCommand {
    static var abstract: String { "Delete protected branch and clear its assets" }
    @OptionGroup var clockwork: Clockwork
  }
  struct DeleteReleaseBranch: ClockworkCommand {
    static var abstract: String { "Delete protected branch and clear its assets" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: "")
    var revoke: Bool = false
  }
  struct DeleteStageTag: ClockworkCommand {
    static var abstract: String { "Delete current stage tag" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ExportBuild: ClockworkCommand {
    static var abstract: String { "Render reserved build and versions to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ExportNextVersions: ClockworkCommand {
    static var abstract: String { "Render current next versions to stdout" }
    @OptionGroup var clockwork: Clockwork
  }
  struct ForwardBranch: ClockworkCommand {
    static var abstract: String { "Fast forward branch to current commit" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "The branch name to forward")
    var name: String
  }
  struct PlayJobs: ClockworkCommand {
    static var abstract: String { "Play job with matching names" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Jobs pipeline id")
    var pipeline: String
    @Argument(help: "Job names to paly")
    var names: [String]
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
        case .lines: return "Interpret stdin as lines array"
        case .json: return "Interpret stdin as json"
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
  struct Requisites: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Subset of requisites management commands",
      subcommands: [
        Erase.self,
        Import.self,
        ImportPkcs12.self,
        ImportProvisions.self,
        ReportExpiring.self,
      ]
    )
    struct Erase: ClockworkCommand {
      static var abstract: String { "Delete keychain and provisions" }
      @OptionGroup var clockwork: Clockwork
    }
    struct Import: ClockworkCommand {
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
    struct ReportExpiring: ClockworkCommand {
      static var abstract: String { "Report expiring provisions and certificates" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Days till expired threashold or 0")
      var days: UInt = 0
    }
  }
  struct ReserveBranchBuild: ClockworkCommand {
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
    @Option(help: "Jobs pipeline id")
    var pipeline: String
    @Argument(help: "Job names to retry")
    var names: [String]
  }
  struct Review: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Subset of review lifecycle management commands",
      subcommands: [
        Accept.self,
        AddLabels.self,
        Approve.self,
        Dequeue.self,
        ExportIntegration.self,
        Own.self,
        Clean.self,
        ReportCustom.self,
        ReserveBuild.self,
        RemoveLabels.self,
        Update.self,
        TriggerPipeline.self,
        Skip.self,
        StartReplication.self,
        StartIntegration.self,
      ]
    )
    struct Accept: ClockworkCommand {
      static var abstract: String { "Accept parent review" }
      @OptionGroup var clockwork: Clockwork
    }
    struct AddLabels: ClockworkCommand {
      static var abstract: String { "Add labels to parent review" }
      @OptionGroup var clockwork: Clockwork
      @Argument(help: "Labels to be added to parent review")
      var labels: [String]
    }
    struct Approve: ClockworkCommand {
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
    struct Clean: ClockworkCommand {
      static var abstract: String { "Clean outdated reviews" }
      @OptionGroup var clockwork: Clockwork
      @Flag(help: "Should ping slackers")
      var remind: Bool = false
    }
    struct Dequeue: ClockworkCommand {
      static var abstract: String { "Dequeue parent review" }
      @OptionGroup var clockwork: Clockwork
    }
    struct ExportIntegration: ClockworkCommand {
      static var abstract: String { "Render integration suitable branches to stdout" }
      @OptionGroup var clockwork: Clockwork
    }
    struct Own: ClockworkCommand {
      static var abstract: String { "Transmith authorship to user" }
      @OptionGroup var clockwork: Clockwork
    }
    struct ReserveBuild: ClockworkCommand {
      static var abstract: String { "Reserve build number for parent review pipeline" }
      @OptionGroup var clockwork: Clockwork
    }
    struct RemoveLabels: ClockworkCommand {
      static var abstract: String { "Remove parent review labels" }
      @OptionGroup var clockwork: Clockwork
      @Argument(help: "Labels to be removed from parent review")
      var labels: [String]
    }
    struct ReportCustom: ClockworkCommand {
      static var abstract: String { "Send preconfigured parent review report" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var custom: Clockwork.ReportCustom
    }
    struct TriggerPipeline: ClockworkCommand {
      static var abstract: String { "Create new pipeline for parent review" }
      @OptionGroup var clockwork: Clockwork
    }
    struct Skip: ClockworkCommand {
      static var abstract: String { "Mark review as emergent" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Review iid to skip approval for")
      var review: UInt
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
    struct Update: ClockworkCommand {
      static var abstract: String { "Update parent review state" }
      @OptionGroup var clockwork: Clockwork
    }
  }
  struct TriggerPipeline: ClockworkCommand {
    static var abstract: String { "Trigger pipeline configured and custom context" }
    @OptionGroup var clockwork: Clockwork
    @Option(help: "Ref to run pipeline on")
    var ref: String
    @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
    var context: [String] = []
  }
  struct UpdatePodSpecs: ClockworkCommand {
    static var abstract: String { "Update cocoapods specs and configured commist" }
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
