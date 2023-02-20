import ArgumentParser
struct Clockwork: ParsableCommand {
  static var version: String { "0.5.0" }
  static let configuration = CommandConfiguration(
    abstract: "Distributed scalable monorepo management tool",
    version: Clockwork.version,
    subcommands: [
      Cocoapods.self,
      Connect.self,
      Flow.self,
      Gitlab.self,
      Requisites.self,
      Render.self,
      Review.self,
      Validate.self,
    ]
  )
  @Option(help: "The path to the profile")
  var profile = ".clockwork.yml"
  struct Cocoapods: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Cocoapods management commands subset",
      version: Clockwork.version,
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
  struct Connect: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Communication commands subset",
      version: Clockwork.version,
      subcommands: [
        Clean.self,
        Signal.self,
      ]
    )
    struct Clean: ClockworkCommand {
      static var abstract: String { "Clean outdated threads" }
      @OptionGroup var clockwork: Clockwork
    }
    struct Signal: ClockworkCommand {
      static var abstract: String { "Send custom preconfigured report" }
      @OptionGroup var clockwork: Clockwork
      @Flag(help: Common.Stdin.help)
      var stdin: Common.Stdin = .ignore
      @Option(help: "Event name to send report for")
      var event: String
      @Argument(help: "Context to make available during rendering")
      var args: [String] = []
    }
  }
  struct Flow: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Subset of flow management commands",
      version: Clockwork.version,
      subcommands: [
        ChangeAccessoryVersion.self,
        ChangeNextVersion.self,
        CreateAccessoryBranch.self,
        CreateDeployTag.self,
        CreateStageTag.self,
        DeleteBranch.self,
        DeleteTag.self,
        ExportVersions.self,
        ReserveBuild.self,
        StartHotfix.self,
        StartRelease.self,
      ]
    )
    struct ChangeAccessoryVersion: ClockworkCommand {
      static var abstract: String { "Change product version for accessory branch" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to change version for")
      var product: String
      @Option(help: "Branch name or current")
      var branch: String = ""
      @Option(help: "Version to set")
      var version: String
    }
    struct ChangeNextVersion: ClockworkCommand {
      static var abstract: String { "Change product next release version" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to change version for")
      var product: String
      @Option(help: "Version to set")
      var version: String
    }
    struct CreateAccessoryBranch: ClockworkCommand {
      static var abstract: String { "Cut custom protected branch" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Name of the branch")
      var name: String
      @Option(help: "Commit sha to cut form or parrent or current")
      var sha: String = ""
    }
    struct CreateDeployTag: ClockworkCommand {
      static var abstract: String { "Create deploy tag on release branch" }
      @OptionGroup var clockwork: Clockwork
    }
    struct CreateStageTag: ClockworkCommand {
      static var abstract: String { "Create stage tag on reserved build" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to make stage tag for")
      var product: String
      @Option(help: "Build number to stage")
      var build: String
    }
    struct DeleteBranch: ClockworkCommand {
      static var abstract: String { "Delete protected branch and clear its assets" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Name of branch to delete or current")
      var name: String = ""
    }
    struct DeleteTag: ClockworkCommand {
      static var abstract: String { "Delete protected tag" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Name of tag to delete or current")
      var name: String = ""
    }
    struct ExportVersions: ClockworkCommand {
      static var abstract: String { "Render versions to stdout" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "If specified ensure product has build reserved")
      var product: String = ""
      @Argument(help: "Context to make available during rendering")
      var args: [String] = []
      @Flag(help: Common.Stdin.help)
      var stdin: Common.Stdin = .ignore
    }
    struct ReserveBuild: ClockworkCommand {
      static var abstract: String { "Reserve build number for current protected branch pipeline" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to make branch for")
      var product: String
    }
    struct StartHotfix: ClockworkCommand {
      static var abstract: String { "Cut hotfix branch from deploy tag or using passed options" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to make branch for")
      var product: String = ""
      @Option(help: "Commit sha to start from")
      var commit: String = ""
      @Option(help: "Version of hotfix")
      var version: String = ""
    }
    struct StartRelease: ClockworkCommand {
      static var abstract: String { "Cut release branch and bump product version" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to make branch for")
      var product: String
      @Option(help: "Commit sha to start from or current")
      var commit: String = ""
    }
}
  struct Gitlab: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Gitlab interaction commands subset",
      version: Clockwork.version,
      subcommands: [
        Artifacts.self,
        Jobs.self,
        Pipeline.self,
        TriggerPipeline.self,
        TriggerReviewPipeline.self,
        User.self,
      ]
    )
    struct Artifacts: ParsableCommand {
      static let configuration = CommandConfiguration(
        abstract: "Subset of jobs artifacts manipulating commands",
        version: Clockwork.version,
        subcommands: [
          LoadFile.self,
        ]
      )
      @Option(help: "Job id to manipulate artifacts of")
      var job: UInt
      struct LoadFile: ParsableCommand {
        static var abstract: String { "Stdouts single job artifacts file" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var artifacts: Artifacts
        @Argument(help: "Path to the file")
        var path: String
      }
    }
    struct Jobs: ParsableCommand {
      static let configuration = CommandConfiguration(
        abstract: "Subset of jobs affecting commands",
        version: Clockwork.version,
        subcommands: [
          Play.self,
          Retry.self,
          Cancel.self,
        ]
      )
      @Flag(help: "Scopes of jobs to look for")
      var scopes: [Scope] = []
      @Option(help: "Pipeline id to affect job on")
      var pipeline: UInt
      struct Cancel: ClockworkCommand {
        static var abstract: String { "Cancel matching jobs" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var jobs: Jobs
        @Argument(help: "Job names to affect")
        var names: [String]
      }
      struct Play: ClockworkCommand {
        static var abstract: String { "Play matching jobs" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var jobs: Jobs
        @Argument(help: "Job names to affect")
        var names: [String]
      }
      struct Retry: ClockworkCommand {
        static var abstract: String { "Retry matching jobs" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var jobs: Jobs
        @Argument(help: "Job names to affect")
        var names: [String]
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
    struct Pipeline: ParsableCommand {
      static let configuration = CommandConfiguration(
        abstract: "Pipeline batch commands subser",
        version: Clockwork.version,
        subcommands: [
          Cancel.self,
          Delete.self,
          Retry.self
        ]
      )
      @Option(help: "Pipeline id to affect")
      var id: UInt
      struct Cancel: ClockworkCommand {
        static var abstract: String { "Cancel all pipeline jobs" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var pipeline: Pipeline
      }
      struct Delete: ClockworkCommand {
        static var abstract: String { "Delete pipeline" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var pipeline: Pipeline
      }
      struct Retry: ClockworkCommand {
        static var abstract: String { "Retry all failed pipeline jobs" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var pipeline: Pipeline
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
    struct TriggerReviewPipeline: ClockworkCommand {
      static var abstract: String { "Create new pipeline for review" }
      @OptionGroup var clockwork: Clockwork
      @Argument(help: "Review id to trigger pipeline for")
      var review: UInt
    }
    struct User: ParsableCommand {
      static let configuration = CommandConfiguration(
        abstract: "Subset of approver manipulations commands",
        version: Clockwork.version,
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
      @Option(help: "Gitlab user login or current")
      var login: String = ""
      struct Activate: ClockworkCommand {
        static var abstract: String { "Activate user" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var user: User
      }
      struct Deactivate: ClockworkCommand {
        static var abstract: String { "Deactivate user" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var user: User
      }
      struct Register: ClockworkCommand {
        static var abstract: String { "Add new user" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var user: User
        @Option(help: "Approver's slack id")
        var slack: String = ""
      }
      struct UnwatchAuthors: ClockworkCommand {
        static var abstract: String { "Remove user from watchers for authors provided in arguments" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var user: User
        @Argument(help: "List of authors to unwatch")
        var args: [String] = []
      }
      struct UnwatchTeams: ClockworkCommand {
        static var abstract: String { "Remove user from watchers for teams provided in arguments" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var user: User
        @Argument(help: "List of teams to unwatch")
        var args: [String] = []
      }
      struct WatchAuthors: ClockworkCommand {
        static var abstract: String { "Add user to watchers for authors provided in arguments" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var user: User
        @Argument(help: "List of authors to watch")
        var args: [String] = []
      }
      struct WatchTeams: ClockworkCommand {
        static var abstract: String { "Add user to watchers for teams provided in arguments" }
        @OptionGroup var clockwork: Clockwork
        @OptionGroup var user: User
        @Argument(help: "List of teams to watch")
        var args: [String] = []
      }
    }
  }
  struct Requisites: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Subset of requisites management commands",
      version: Clockwork.version,
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
  struct Render: ClockworkCommand {
    static var abstract: String { "Renders custom template to stdout" }
    @OptionGroup var clockwork: Clockwork
    @Flag(help: Common.Stdin.help)
    var stdin: Common.Stdin = .ignore
    @Option(help: "Template name to render")
    var template: String
    @Argument(help: "Context to make available during rendering")
    var args: [String] = []
  }
  struct Review: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Subset of review lifecycle management commands",
      version: Clockwork.version,
      subcommands: [
        Accept.self,
        AddLabels.self,
        Approve.self,
        Dequeue.self,
        Enqueue.self,
        ExportTargets.self,
        List.self,
        Own.self,
        Patch.self,
        Rebase.self,
        Remind.self,
        RemoveLabels.self,
        ReserveBuild.self,
        TriggerPipeline.self,
        Skip.self,
        StartDuplication.self,
        StartIntegration.self,
        StartPropogation.self,
        StartReplication.self,
        Unown.self,
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
      @Flag(help: "Should approve persist regardless of further commits")
      var advance: Bool = false
    }
    struct Dequeue: ClockworkCommand {
      static var abstract: String { "Dequeue parent review" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Merge request iid or parent merge iid")
      var iid: UInt = 0
    }
    struct Enqueue: ClockworkCommand {
      static var abstract: String { "Update parent review state" }
      @OptionGroup var clockwork: Clockwork
    }
    struct ExportTargets: ClockworkCommand {
      static var abstract: String { "Render integration suitable branches to stdout" }
      @OptionGroup var clockwork: Clockwork
      @Argument(help: "Context to make available during rendering")
      var args: [String] = []
      @Flag(help: "Should read stdin and pass as a context for generation")
      var stdin: Common.Stdin = .ignore
    }
    struct List: ClockworkCommand {
      static var abstract: String { "List all reviews to be approved" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Approver login or all active users")
      var user: String = ""
    }
    struct Own: ClockworkCommand {
      static var abstract: String { "Add user to authors" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Approver login or job runner")
      var user: String = ""
      @Option(help: "Merge request iid or parent merge iid")
      var iid: UInt = 0
    }
    struct Patch: ClockworkCommand {
      static var abstract: String { "Apply parrent job generated patch" }
      @OptionGroup var clockwork: Clockwork
      @Flag(help: "Should skip commit approval")
      var skip: Bool = false
      @Option(help: "Commit message")
      var message: String
    }
    struct Rebase: ClockworkCommand {
      static var abstract: String { "Rebase parent review" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Merge request iid or parent merge iid")
      var iid: UInt = 0
    }
    struct Remind: ClockworkCommand {
      static var abstract: String { "Ask approvers to pay attention" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Merge request iid or parent merge iid")
      var iid: UInt = 0
    }
    struct RemoveLabels: ClockworkCommand {
      static var abstract: String { "Remove parent review labels" }
      @OptionGroup var clockwork: Clockwork
      @Argument(help: "Labels to be removed from parent review")
      var labels: [String]
    }
    struct ReserveBuild: ClockworkCommand {
      static var abstract: String { "Reserve build number for parrent review pipeline" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to make branch for")
      var product: String
    }
    struct TriggerPipeline: ClockworkCommand {
      static var abstract: String { "Create new pipeline for parent review" }
      @OptionGroup var clockwork: Clockwork
    }
    struct Skip: ClockworkCommand {
      static var abstract: String { "Mark review as emergent" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Merge request iid")
      var iid: UInt
    }
    struct StartDuplication: ClockworkCommand {
      static var abstract: String { "Create duplication review" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Duplicated commit sha")
      var fork: String
      @Option(help: "Duplication target branch name")
      var target: String
      @Option(help: "Duplication source branch name")
      var source: String
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
    struct StartPropogation: ClockworkCommand {
      static var abstract: String { "Create propogation review" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Propogated commit sha")
      var fork: String
      @Option(help: "Propogation target branch name")
      var target: String
      @Option(help: "Propogation source branch name")
      var source: String
    }
    struct StartReplication: ClockworkCommand {
      static var abstract: String { "Create replication review" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Propogated commit sha")
      var fork: String
      @Option(help: "Propogation target branch name")
      var target: String
      @Option(help: "Propogation source branch name")
      var source: String
    }
    struct Unown: ClockworkCommand {
      static var abstract: String { "Remove user from authors" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Approver login or job runner")
      var user: String = ""
      @Option(help: "Merge request iid or parent merge iid")
      var iid: UInt = 0
    }
    struct Update: ClockworkCommand {
      static var abstract: String { "Update status for stuck reviews" }
      @OptionGroup var clockwork: Clockwork
      @Flag(help: "Should ping slackers")
      var remind: Bool = false
    }
  }
  struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Validation commands subset",
      version: Clockwork.version,
      subcommands: [
        ConflictMarkers.self,
        FileTaboos.self,
        UnownedCode.self,
      ]
    )
    @Flag(help: "Should render json to stdout")
    var json = false
    struct ConflictMarkers: ClockworkCommand {
      static var abstract: String { "Ensure no conflict markers against base" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var validate: Validate
      @Option(help: "The name of target branch")
      var target: String
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
enum Common {
  enum Stdin: EnumerableFlag {
    static var help: ArgumentHelp { "Should read stdin and pass as a context for generation" }
    case ignore
    case lines
    case json
    case yaml
    static func help(for value: Self) -> ArgumentHelp? {
      switch value {
      case .ignore: return "Do not read stdin"
      case .lines: return "Interpret stdin as lines array"
      case .json: return "Interpret stdin as json"
      case .yaml: return "Interpret stdin as yaml"
      }
    }
  }
}
