import ArgumentParser
import Facility
import FacilityPure
import FacilityFair
struct Clockwork: ParsableCommand {
  static var version: String { "0.6.0" }
  static let configuration = CommandConfiguration(
    abstract: "Distributed scalable monorepo management tool",
    version: Clockwork.version,
    subcommands: [
      Cocoapods.self,
      Connect.self,
      Flow.self,
      Fusion.self,
      Requisites.self,
      Render.self,
      Review.self,
      User.self,
      Validate.self,
    ]
  )
  @Option(help: "The path to the profile")
  var profile = "Clockwork/Profile.yml"
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
      func handle(repo: Repo) throws -> Performer {
        UseCase.cocoapodsResetSpecs()
      }
    }
    struct UpdateSpecs: ClockworkCommand {
      static var abstract: String { "Update cocoapods specs and configured commist" }
      @OptionGroup var clockwork: Clockwork
      func handle(repo: Repo) throws -> Performer {
        UseCase.cocoapodsUpdateSpecs()
      }
    }
  }
  struct Connect: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Communication commands subset",
      version: Clockwork.version,
      subcommands: [
        Clean.self,
        ExecuteContract.self,
        Signal.self,
        Trigger.self,
      ]
    )
    struct Clean: ClockworkCommand {
      static var abstract: String { "Clean outdated threads" }
      @OptionGroup var clockwork: Clockwork
      func handle(repo: Repo) throws -> Performer {
        UseCase.connectClean()
      }
    }
    struct ExecuteContract: ClockworkCommand {
      static var abstract: String { "Execute contract" }
      @OptionGroup var clockwork: Clockwork
      func handle(repo: Repo) throws -> Performer {
        UseCase.connectExecuteContract()
      }
    }
    struct Signal: ClockworkCommand {
      static var abstract: String { "Send custom preconfigured report" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var stdin: Common.Parse
      @Option(help: "Event name to send report for")
      var event: String
      @Argument(help: "Context to make available during rendering")
      var args: [String] = []
      func handle(repo: Repo) throws -> Performer {
        try UseCase.connectSignal(
          event: event,
          args: args,
          stdin: repo.parse(stdin)
        )
      }
    }
    struct Trigger: ClockworkCommand {
      static var abstract: String { "Trigger default branch child pipeline from protected ref" }
      @OptionGroup var clockwork: Clockwork
      @Argument(help: "Additional variables to pass to pipeline in format KEY=value")
      var variables: [String] = []
      func handle(repo: Repo) throws -> Performer {
        UseCase.connectTriggerPipeline(variables: variables)
      }
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
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowChangeNext(product: product, version: version)
      }
    }
    struct ChangeNextVersion: ClockworkCommand {
      static var abstract: String { "Change product next release version" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to change version for")
      var product: String
      @Option(help: "Version to set")
      var version: String
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowChangeNext(product: product, version: version)
      }
    }
    struct CreateAccessoryBranch: ClockworkCommand {
      static var abstract: String { "Cut custom protected branch" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Name of the branch")
      var name: String
      @Option(help: "Commit sha to cut form or parrent or current")
      var sha: String = ""
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowCreateAccessory(name: name, commit: sha)
      }
    }
    struct CreateDeployTag: ClockworkCommand {
      static var abstract: String { "Create deploy tag on release branch" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Release branch name or current")
      var branch: String = ""
      @Option(help: "Commit sha to make deploy on or current")
      var sha: String = ""
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowCreateDeploy(branch: branch, commit: sha)
      }
    }
    struct CreateStageTag: ClockworkCommand {
      static var abstract: String { "Create stage tag on reserved build" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to make stage tag for")
      var product: String
      @Option(help: "Build number to stage")
      var build: String
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowCreateStage(product: product, build: build)
      }
    }
    struct DeleteBranch: ClockworkCommand {
      static var abstract: String { "Delete protected branch and clear its assets" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Name of branch to delete or current")
      var name: String = ""
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowDeleteBranch(name: name)
      }
    }
    struct DeleteTag: ClockworkCommand {
      static var abstract: String { "Delete protected tag" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Name of tag to delete or current")
      var name: String = ""
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowDeleteTag(name: name)
      }
    }
    struct ExportVersions: ClockworkCommand {
      static var abstract: String { "Render versions to stdout" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "If specified ensure product has build reserved")
      var product: String = ""
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowExportVersions(product: product)
      }
    }
    struct ReserveBuild: ClockworkCommand {
      static var abstract: String { "Reserve build number for current protected branch pipeline" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to make branch for")
      var product: String
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowReserveBuild(product: product)
      }
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
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowStartHotfix(product: product, commit: commit, version: version)
      }
    }
    struct StartRelease: ClockworkCommand {
      static var abstract: String { "Cut release branch and bump product version" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Product name to make branch for")
      var product: String
      @Option(help: "Commit sha to start from or current")
      var commit: String = ""
      func handle(repo: Repo) throws -> Performer {
        UseCase.flowStartRelease(product: product, commit: commit)
      }
    }
  }
  struct Fusion: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Review lifecycle management command subset",
      version: Clockwork.version,
      subcommands: [
        Duplicate.self,
        Export.self,
        Integrate.self,
        Propogate.self,
        Replicate.self,
      ]
    )
    @Option(help: "Fusion commit sha")
    var fork: String
    @Option(help: "Fusion target branch name")
    var target: String
    @Option(help: "Fusion source branch name")
    var source: String
    struct Duplicate: ClockworkCommand {
      static var abstract: String { "Create duplication review" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var fusion: Fusion
      func handle(repo: Repo) throws -> Performer {
        UseCase.fusionStart(
          fork: fusion.fork,
          target: fusion.target,
          source: fusion.source,
          prefix: .duplicate
        )
      }
    }
    struct Integrate: ClockworkCommand {
      static var abstract: String { "Create integration review" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var fusion: Fusion
      func handle(repo: Repo) throws -> Performer {
        UseCase.fusionStart(
          fork: fusion.fork,
          target: fusion.target,
          source: fusion.source,
          prefix: .integrate
        )
      }
    }
    struct Export: ClockworkCommand {
      static var abstract: String { "Render integration suitable branches to stdout" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Fusion commit sha")
      var fork: String
      @Option(help: "Fusion source branch name")
      var source: String
      func handle(repo: Repo) throws -> Performer {
        UseCase.fusionExport(fork: fork, source: source)
      }
    }
    struct Propogate: ClockworkCommand {
      static var abstract: String { "Create propogation review" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var fusion: Fusion
      func handle(repo: Repo) throws -> Performer {
        UseCase.fusionStart(
          fork: fusion.fork,
          target: fusion.target,
          source: fusion.source,
          prefix: .propogate
        )
      }
    }
    struct Replicate: ClockworkCommand {
      static var abstract: String { "Create replication review" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var fusion: Fusion
      func handle(repo: Repo) throws -> Performer {
        UseCase.fusionStart(
          fork: fusion.fork,
          target: fusion.target,
          source: fusion.source,
          prefix: .replicate
        )
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
        CheckExpire.self,
      ]
    )
    @Argument(help: "Requisite to install or all")
    var requisites: [String] = []
    struct Erase: ClockworkCommand {
      static var abstract: String { "Delete keychain and provisions" }
      @OptionGroup var clockwork: Clockwork
      func handle(repo: Repo) throws -> Performer {
        UseCase.requisitesClear()
      }
    }
    struct Import: ClockworkCommand {
      static var abstract: String { "Import p12 and provisions" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var requisites: Requisites
      func handle(repo: Repo) throws -> Performer {
        UseCase.requisitesImport(
          pkcs12: true,
          provisions: true,
          requisites: requisites.requisites
        )
      }
    }
    struct ImportPkcs12: ClockworkCommand {
      static var abstract: String { "Import p12" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var requisites: Requisites
      func handle(repo: Repo) throws -> Performer {
        UseCase.requisitesImport(
          pkcs12: true,
          provisions: false,
          requisites: requisites.requisites
        )
      }
    }
    struct ImportProvisions: ClockworkCommand {
      static var abstract: String { "Import provisions" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var requisites: Requisites
      func handle(repo: Repo) throws -> Performer {
        UseCase.requisitesImport(
          pkcs12: false,
          provisions: true,
          requisites: requisites.requisites
        )
      }
    }
    struct CheckExpire: ClockworkCommand {
      static var abstract: String { "Report expiring provisions and certificates" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Days till expired threashold or 0")
      var days: UInt = 0
      @Flag(help: "Should render json to stdout")
      var stdout = false
      func handle(repo: Repo) throws -> Performer {
        UseCase.requisitesCheckExpire(days: days, stdout: stdout)
      }
    }
  }
  struct Render: ClockworkCommand {
    static var abstract: String { "Renders custom template to stdout" }
    @OptionGroup var clockwork: Clockwork
    @OptionGroup var stdin: Common.Parse
    @Option(help: "Template name to render")
    var template: String
    @Argument(help: "Context to make available during rendering")
    var args: [String] = []
    func handle(repo: Repo) throws -> Performer {
      try UseCase.render(template: template, stdin: repo.parse(stdin), args: args)
    }
  }
  struct Review: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Review lifecycle management command subset",
      version: Clockwork.version,
      subcommands: [
        Accept.self,
        AddLabels.self,
        Approve.self,
        Dequeue.self,
        Enqueue.self,
        List.self,
        Own.self,
        Patch.self,
        Rebase.self,
        Remind.self,
        RemoveLabels.self,
        Skip.self,
        Unown.self,
        Update.self,
      ]
    )
    @Option(help: "Merge request iid or parent merge iid")
    var iid: UInt = 0
    struct Accept: ClockworkCommand {
      static var abstract: String { "Accept parent review" }
      @OptionGroup var clockwork: Clockwork
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewAccept()
      }
    }
    struct AddLabels: ClockworkCommand {
      static var abstract: String { "Add labels to parent review" }
      @OptionGroup var clockwork: Clockwork
      @Argument(help: "Labels to be added to parent review")
      var labels: [String]
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewLabels(labels: labels, add: true)
      }
    }
    struct Approve: ClockworkCommand {
      static var abstract: String { "Approve parent review" }
      @OptionGroup var clockwork: Clockwork
      @Flag(help: "Should approve persist regardless of further commits")
      var advance: Bool = false
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewApprove(advance: advance)
      }
    }
    struct Dequeue: ClockworkCommand {
      static var abstract: String { "Dequeue parent review" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var review: Review
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewDequeue(iid: review.iid)
      }
    }
    struct Enqueue: ClockworkCommand {
      static var abstract: String { "Update parent review state" }
      @OptionGroup var clockwork: Clockwork
      @Argument(help: "Jobs to start before accepting merge")
      var jobs: [String] = []
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewEnqueue(jobs: jobs)
      }
    }
    struct List: ClockworkCommand {
      static var abstract: String { "List all actual reviews" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Approver login or all active users")
      var user: String = ""
      @Flag(help: "Owned or approved reviews")
      var own: Bool = false
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewList(user: user, own: own)
      }
    }
    struct Own: ClockworkCommand {
      static var abstract: String { "Add user to authors" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Approver login or job runner")
      var user: String = ""
      @OptionGroup var review: Review
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewOwnage(user: user, iid: review.iid, own: true)
      }
    }
    struct Patch: ClockworkCommand {
      static var abstract: String { "Apply patch to current MR sha" }
      @OptionGroup var clockwork: Clockwork
      @Flag(help: "Should skip commit approval")
      var skip: Bool = false
      @Argument(help: "Additional context")
      var args: [String] = []
      func handle(repo: Repo) throws -> Performer {
        try UseCase.reviewPatch(skip: skip, args: args, patch: repo.sh.stdin())
      }
    }
    struct Rebase: ClockworkCommand {
      static var abstract: String { "Rebase parent review" }
      @OptionGroup var clockwork: Clockwork
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewRebase()
      }
    }
    struct Remind: ClockworkCommand {
      static var abstract: String { "Ask approvers to pay attention" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var review: Review
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewRemind(iid: review.iid)
      }
    }
    struct RemoveLabels: ClockworkCommand {
      static var abstract: String { "Remove parent review labels" }
      @OptionGroup var clockwork: Clockwork
      @Argument(help: "Labels to be removed from parent review")
      var labels: [String]
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewLabels(labels: labels, add: false)
      }
    }
    struct Skip: ClockworkCommand {
      static var abstract: String { "Mark review as emergent" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Merge request iid")
      var iid: UInt
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewSkip(iid: iid)
      }
    }
    struct Unown: ClockworkCommand {
      static var abstract: String { "Remove user from authors" }
      @OptionGroup var clockwork: Clockwork
      @Option(help: "Approver login or job runner")
      var user: String = ""
      @OptionGroup var review: Review
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewOwnage(user: user, iid: review.iid, own: false)
      }
    }
    struct Update: ClockworkCommand {
      static var abstract: String { "Update status for stuck reviews" }
      @OptionGroup var clockwork: Clockwork
      func handle(repo: Repo) throws -> Performer {
        UseCase.reviewUpdate()
      }
    }
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
      func handle(repo: Repo) throws -> Performer {
        UseCase.userActivity(login: user.login, active: true)
      }
    }
    struct Deactivate: ClockworkCommand {
      static var abstract: String { "Deactivate user" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var user: User
      func handle(repo: Repo) throws -> Performer {
        UseCase.userActivity(login: user.login, active: false)
      }
    }
    struct Register: ClockworkCommand {
      static var abstract: String { "Add new user" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var user: User
      @Option(help: "Approver's slack id")
      var slack: String = ""
      @Option(help: "Approver's rocket id")
      var rocket: String = ""
      func handle(repo: Repo) throws -> Performer {
        UseCase.userRegister(login: user.login, slack: slack, rocket: rocket)
      }
    }
    struct UnwatchAuthors: ClockworkCommand {
      static var abstract: String { "Remove user from watchers for authors provided in arguments" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var user: User
      @Argument(help: "List of authors to unwatch")
      var args: [String] = []
      func handle(repo: Repo) throws -> Performer {
        UseCase.userWatchAuthors(login: user.login, watch: args, add: false)
      }
    }
    struct UnwatchTeams: ClockworkCommand {
      static var abstract: String { "Remove user from watchers for teams provided in arguments" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var user: User
      @Argument(help: "List of teams to unwatch")
      var args: [String] = []
      func handle(repo: Repo) throws -> Performer {
        UseCase.userWatchTeams(login: user.login, watch: args, add: false)
      }
    }
    struct WatchAuthors: ClockworkCommand {
      static var abstract: String { "Add user to watchers for authors provided in arguments" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var user: User
      @Argument(help: "List of authors to watch")
      var args: [String] = []
      func handle(repo: Repo) throws -> Performer {
        UseCase.userWatchAuthors(login: user.login, watch: args, add: true)
      }
    }
    struct WatchTeams: ClockworkCommand {
      static var abstract: String { "Add user to watchers for teams provided in arguments" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var user: User
      @Argument(help: "List of teams to watch")
      var args: [String] = []
      func handle(repo: Repo) throws -> Performer {
        UseCase.userWatchTeams(login: user.login, watch: args, add: true)
      }
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
    var stdout = false
    struct ConflictMarkers: ClockworkCommand {
      static var abstract: String { "Ensure no conflict markers against base" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var validate: Validate
      @Option(help: "The name of target branch")
      var target: String
      func handle(repo: Repo) throws -> Performer {
        UseCase.validateConflictMarkers(target: target, stdout: validate.stdout)
      }
    }
    struct FileTaboos: ClockworkCommand {
      static var abstract: String { "Ensure files match defined rules" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var validate: Validate
      func handle(repo: Repo) throws -> Performer {
        UseCase.validateFileTaboos(stdout: validate.stdout)
      }
    }
    struct UnownedCode: ClockworkCommand {
      static var abstract: String { "Ensure no unowned files" }
      @OptionGroup var clockwork: Clockwork
      @OptionGroup var validate: Validate
      func handle(repo: Repo) throws -> Performer {
        UseCase.validateUnownedCode(stdout: validate.stdout)
      }
    }
  }
}
protocol ClockworkCommand: ParsableCommand {
  var clockwork: Clockwork { get }
  static var abstract: String { get }
  func handle(repo: Repo) throws -> Performer
}
extension ClockworkCommand {
  static var configuration: CommandConfiguration {
    .init(abstract: abstract)
  }
  mutating func run() throws {
    guard try Repo.handle(profile: clockwork.profile, handler: handle(repo:))
    else { throw Thrown("Execution considered unsuccessful") }
  }
}
enum Common {
  struct Parse: ParsableArguments {
    @Option(help: "How should stdin be interpreted")
    var stdin: Stdin = .ignore
    enum Stdin: String, CaseIterable, ExpressibleByArgument {
      case ignore
      case lines
      case json
      case yaml
    }
  }
}
