import Foundation
import Facility
import FacilityPure
public enum UseCase {
  public static func cocoapodsResetSpecs() -> Performer {
    CocoapodsResetSpecs()
  }
  public static func cocoapodsUpdateSpecs() -> Performer {
    CocoapodsUpdateSpecs()
  }
  public static func connectClean() -> Performer {
    ConnectClean()
  }
  public static func connectExecuteContract() -> Performer {
    ConnectExecuteContract()
  }
  public static func connectSignal(
    event: String,
    args: [String],
    stdin: AnyCodable?
  ) -> Performer {
    ConnectSignal(event: event, args: args, stdin: stdin)
  }
  public static func connectTriggerPipeline(
    variables: [String]
  ) -> Performer {
    ConnectTriggerPipeline(variables: variables)
  }
  public static func flowChangeAccessory(
    product: String,
    branch: String,
    version: String
  ) -> Performer {
    FlowChangeAccessory(product: product, branch: branch, version: version)
  }
  public static func flowChangeNext(
    product: String,
    version: String
  ) -> Performer {
    FlowChangeNext(product: product, version: version)
  }
  public static func flowCreateAccessory(
    name: String,
    commit: String
  ) -> Performer {
    FlowCreateAccessory(name: name, commit: commit)
  }
  public static func flowCreateDeploy(
    branch: String,
    commit: String
  ) -> Performer {
    FlowCreateDeploy(branch: branch, commit: commit)
  }
  public static func flowCreateStage(
    product: String,
    build: String
  ) -> Performer {
    FlowCreateStage(product: product, build: build)
  }
  public static func flowDeleteBranch(
    name: String
  ) -> Performer {
    FlowDeleteBranch(name: name)
  }
  public static func flowDeleteTag(
    name: String
  ) -> Performer {
    FlowDeleteTag(name: name)
  }
  public static func flowExportVersions(
    product: String
  ) -> Performer {
    FlowExportVersions(product: product)
  }
  public static func flowReserveBuild(
    product: String
  ) -> Performer {
    FlowReserveBuild(product: product)
  }
  public static func flowStartHotfix(
    product: String,
    commit: String,
    version: String
  ) -> Performer {
    FlowStartHotfix(product: product, commit: commit, version: version)
  }
  public static func flowStartRelease(
    product: String,
    commit: String
  ) -> Performer {
    FlowStartRelease(product: product, commit: commit)
  }
  public static func fusionExport(
    fork: String,
    source: String
  ) -> Performer {
    FusionExport(fork: fork, source: source)
  }
  public static func fusionStart(
    fork: String,
    target: String,
    source: String,
    prefix: Review.Fusion.Prefix
  ) -> Performer {
    FusionStart(fork: fork, target: target, source: source, prefix: prefix)
  }
  public static func requisitesCheckExpire(
    days: UInt,
    stdout: Bool
  ) -> Performer {
    RequisitesCheckExpire(days: days, stdout: stdout)
  }
  public static func requisitesClear() -> Performer {
    RequisitesClear()
  }
  public static func requisitesImport(
    pkcs12: Bool,
    provisions: Bool,
    requisites: [String]
  ) -> Performer {
    RequisitesImport(pkcs12: pkcs12, provisions: provisions, requisites: requisites)
  }
  public static func render(
    template: String,
    stdin: AnyCodable?,
    args: [String]
  ) -> Performer {
    Render(template: template, stdin: stdin, args: args)
  }
  public static func reviewAccept() -> Performer {
    ReviewAccept()
  }
  public static func reviewApprove(
    advance: Bool
  ) -> Performer {
    ReviewApprove(advance: advance)
  }
  public static func reviewDequeue(
    iid: UInt
  ) -> Performer {
    ReviewDequeue(iid: iid)
  }
  public static func reviewEnqueue(
    jobs: [String]
  ) -> Performer {
    ReviewEnqueue(jobs: jobs)
  }
  public static func reviewLabels(
    labels: [String],
    add: Bool
  ) -> Performer {
    ReviewLabels(labels: labels, add: add)
  }
  public static func reviewList(
    user: String,
    own: Bool
  ) -> Performer {
    ReviewList(user: user, own: own)
  }
  public static func reviewOwnage(
    user: String,
    iid: UInt,
    own: Bool
  ) -> Performer {
    ReviewOwnage(user: user, iid: iid, own: own)
  }
  public static func reviewPatch(
    skip: Bool,
    args: [String],
    patch: Data?
  ) -> Performer {
    ReviewPatch(skip: skip, args: args, patch: patch)
  }
  public static func reviewRebase() -> Performer {
    ReviewRebase()
  }
  public static func reviewRemind(iid: UInt) -> Performer {
    ReviewRemind(iid: iid)
  }
  public static func reviewSkip(
    iid: UInt
  ) -> Performer {
    ReviewSkip(iid: iid)
  }
  public static func reviewUpdate() -> Performer {
    ReviewUpdate()
  }
  public static func userActivity(
    login: String,
    active: Bool
  ) -> Performer {
    UserActivity(login: login, active: active)
  }
  public static func userRegister(
    login: String,
    slack: String,
    rocket: String
  ) -> Performer {
    UserRegister(login: login, slack: slack, rocket: rocket)
  }
  public static func userWatchAuthors(
    login: String,
    watch: [String],
    add: Bool
  ) -> Performer {
    UserWatchAuthors(login: login, watch: watch, add: add)
  }
  public static func userWatchTeams(
    login: String,
    watch: [String],
    add: Bool
  ) -> Performer {
    UserWatchTeams(login: login, watch: watch, add: add)
  }
  public static func validateConflictMarkers(
    target: String,
    stdout: Bool
  ) -> Performer {
    ValidateConflictMarkers(target: target, stdout: stdout)
  }
  public static func validateFileTaboos(
    stdout: Bool
  ) -> Performer {
    ValidateFileTaboos(stdout: stdout)
  }
  public static func validateUnownedCode(
    stdout: Bool
  ) -> Performer {
    ValidateUnownedCode(stdout: stdout)
  }
}
