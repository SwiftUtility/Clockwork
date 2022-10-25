import ArgumentParser
struct Clockwork: ParsableCommand {
  static var version: String { "0.4.0" }
  @Option(help: "The path to the profile")
  var profile = ".clockwork.yml"
  static let configuration = CommandConfiguration(
    abstract: "Distributed scalable monorepo management tool",
    version: Self.version,
    subcommands: [
      Flow.self,
      Pipeline.self,
      Pods.self,
      Report.self,
      Requisites.self,
      Review.self,
      Validate.self,
    ]
  )
  struct Flow: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Subset of flow management commands",
      subcommands: [
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
        ExportVersions.self,
        ForwardBranch.self,
        ReserveBuild.self,
      ]
    )
    struct ChangeVersion: ClockworkCommand {
      static var abstract: String { "Change product version" }
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
    struct ExportVersions: ClockworkCommand {
      static var abstract: String { "Render current next versions to stdout" }
      @OptionGroup var clockwork: Clockwork
    }
    struct ForwardBranch: ClockworkCommand {
      static var abstract: String { "Fast forward branch to current commit" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "The branch name to forward")
      var name: String
    }
    struct ReserveBuild: ClockworkCommand {
      static var abstract: String { "Reserve build number for current protected branch pipeline" }
      @OptionGroup var clockwork: Clockwork
    }
  }
  struct Pipeline: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Distributed scalable monorepo management tool",
      subcommands: [
        Cancel.self,
        Delete.self,
        Jobs.self,
        Trigger.self,
        Retry.self
      ]
    )
    struct Cancel: ClockworkCommand {
      static var abstract: String { "Cancel all pipeline jobs" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Pipeline id to cancel jobs on")
      var id: UInt
    }
    struct Delete: ClockworkCommand {
      static var abstract: String { "Delete pipeline" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Pipeline id to delete")
      var id: UInt
    }
    struct Jobs: ParsableCommand {
      static let configuration = CommandConfiguration(
        abstract: "Subset of jobs affecting commands",
        subcommands: [
          Play.self,
          Retry.self,
          Cancel.self,
        ]
      )
      @Flag(help: "Scopes of jobs to look for")
      var scopes: [Scope] = []
      @Argument(help: "Job names to affect")
      var names: [String]
      @Option(help: "Pipeline id to affect job on")
      var id: UInt
      struct Cancel: ClockworkCommand {
        static var abstract: String { "Cancel matching jobs" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var jobs: Jobs
      }
      struct Play: ClockworkCommand {
        static var abstract: String { "Play matching jobs" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var jobs: Jobs
      }
      struct Retry: ClockworkCommand {
        static var abstract: String { "Retry matching jobs" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var jobs: Jobs
      }
      enum Scope: EnumerableFlag {
        case canceled
        case created
        case failed
        case manual
        case pending
        case running
        case success
      }
    }
    struct Trigger: ClockworkCommand {
      static var abstract: String { "Trigger pipeline configured and custom context" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Ref to run pipeline on")
      var ref: String
      @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
      var context: [String] = []
    }
    struct Retry: ClockworkCommand {
      static var abstract: String { "Retry all failed pipeline jobs" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Pipeline id to retry jobs on")
      var id: UInt
    }
  }
  struct Pods: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Distributed scalable monorepo management tool",
      subcommands: [
        ResetSpecs.self,
        UpdateSpecs.self,
      ]
    )
    struct ResetSpecs: ClockworkCommand {
      static var abstract: String { "Reset cocoapods specs to configured commits" }
      @OptionGroup var clockwork: Clockwork
    }
    struct UpdateSpecs: ClockworkCommand {
      static var abstract: String { "Update cocoapods specs and configured commist" }
      @OptionGroup var clockwork: Clockwork
    }
  }
  struct Report: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Subset preconfigured report sending commands",
      subcommands: [
        Custom.self,
        ReleaseThread.self,
        ReviewThread.self,
      ]
    )
    @Flag(help: "Should read stdin and pass as a context for generation")
    var stdin: Stdin = .ignore
    @Option(help: "Event name to send report for")
    var event: String
    struct Custom: ClockworkCommand {
      static var abstract: String { "Send custom preconfigured report" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var report: Report
    }
    struct ReleaseThread: ClockworkCommand {
      static var abstract: String { "Send preconfigured release related report" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var report: Report
    }
    struct ReviewThread: ClockworkCommand {
      static var abstract: String { "Send preconfigured review related report" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var report: Report
    }
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
  struct Review: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Subset of review lifecycle management commands",
      subcommands: [
        Accept.self,
        AddLabels.self,
        Approve.self,
        Approver.self,
        Clean.self,
        Dequeue.self,
        ExportIntegration.self,
        Own.self,
        ReserveBuild.self,
        RemoveLabels.self,
        TriggerPipeline.self,
        Skip.self,
        StartReplication.self,
        StartIntegration.self,
        Update.self,
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
        @Argument(help: "List of authors to unwatch")
        var args: [String] = []
      }
      struct UnwatchTeams: ClockworkCommand {
        static var abstract: String { "Remove user from watchers for teams provided in arguments" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var approver: Approver
        @Argument(help: "List of teams to unwatch")
        var args: [String] = []
      }
      struct WatchAuthors: ClockworkCommand {
        static var abstract: String { "Add user to watchers for authors provided in arguments" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var approver: Approver
        @Argument(help: "List of authors to watch")
        var args: [String] = []
      }
      struct WatchTeams: ClockworkCommand {
        static var abstract: String { "Add user to watchers for teams provided in arguments" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var approver: Approver
        @Argument(help: "List of teams to watch")
        var args: [String] = []
      }
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
    struct TriggerPipeline: ClockworkCommand {
      static var abstract: String { "Create new pipeline for parent review" }
      @OptionGroup var clockwork: Clockwork
    }
    struct Skip: ClockworkCommand {
      static var abstract: String { "Mark review as emergent" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Review iid to skip approval for")
      var id: UInt
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
  struct Validate: ParsableCommand {
    @Flag(help: "Should render json to stdout")
    var json = false
    static let configuration = CommandConfiguration(
      abstract: "Distributed scalable monorepo management tool",
      subcommands: [
        ConflictMarkers.self,
        FileTaboos.self,
        UnownedCode.self,
      ]
    )
    struct ConflictMarkers: ClockworkCommand {
      static var abstract: String { "Ensure no conflict markers against base" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var validate: Validate
      @Option(help: "The commit sha to diff with")
      var base: String
    }
    struct FileTaboos: ClockworkCommand {
      static var abstract: String { "Ensure files match defined rules" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var validate: Validate
      @Flag(help: "Should render json to stdout")
      var json = false
    }
    struct UnownedCode: ClockworkCommand {
      static var abstract: String { "Ensure no unowned files" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var validate: Validate
    }
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
