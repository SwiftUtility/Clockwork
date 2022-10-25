import Foundation
import Facility
import FacilityPure
import FacilityFair
protocol RunnableCommand: ClockworkCommand {
  func run(cfg: Configuration) throws -> Bool
}
extension RunnableCommand {
  mutating func run() throws {
    SideEffects.reportMayDay = { mayDay in Assembler.writeStderr("""
      ⚠️⚠️⚠️
      Please submit an issue at https://github.com/SwiftUtility/Clockwork/issues/new/choose
      Version: \(Clockwork.version)
      What: \(mayDay.what)
      File: \(mayDay.file)
      Line: \(mayDay.line)
      ⚠️⚠️⚠️
      """
    )}
    SideEffects.printDebug = Assembler.writeStderr
    let cfg = try Assembler.configurator.configure(
      profile: clockwork.profile,
      env: Assembler.environment
    )
    try Lossy(cfg)
      .map(run(cfg:))
      .reduceError(cfg, Assembler.reporter.report(cfg:error:))
      .reduce(cfg, Assembler.reporter.finish(cfg:success:))
      .get()
  }
}
extension Clockwork.Flow.ChangeVersion: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.changeVersion(cfg: cfg, product: product, next: next, version: version)
  }
}
extension Clockwork.Flow.CreateAccessoryBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createAccessoryBranch(cfg: cfg, name: name)
  }
}
extension Clockwork.Flow.CreateDeployTag: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createDeployTag(cfg: cfg)
  }
}
extension Clockwork.Flow.CreateHotfixBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createHotfixBranch(cfg: cfg)
  }
}
extension Clockwork.Flow.CreateReleaseBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createReleaseBranch(cfg: cfg, product: product)
  }
}
extension Clockwork.Flow.CreateStageTag: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.stageBuild(cfg: cfg, product: product, build: build)
  }
}
extension Clockwork.Flow.DeleteAccessoryBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.deleteBranch(cfg: cfg, revoke: nil)
  }
}
extension Clockwork.Flow.DeleteReleaseBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.deleteBranch(cfg: cfg, revoke: revoke)
  }
}
extension Clockwork.Flow.DeleteStageTag: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.deleteStageTag(cfg: cfg)
  }
}
extension Clockwork.Flow.ExportBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.renderBuild(cfg: cfg)
  }
}
extension Clockwork.Flow.ExportVersions: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.renderNextVersions(cfg: cfg)
  }
}
extension Clockwork.Flow.ForwardBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.forwardBranch(cfg: cfg, name: name)
  }
}
extension Clockwork.Flow.ReserveBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reserveBranchBuild(cfg: cfg)
  }
}
extension Clockwork.Pipeline.Cancel: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectPipeline(cfg: cfg, id: id, action: .cancel)
  }
}
extension Clockwork.Pipeline.Delete: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectPipeline(cfg: cfg, id: id, action: .delete)
  }
}
extension Clockwork.Pipeline.Jobs.Cancel: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.affectJobs(
    cfg: cfg,
    pipeline: id,
    names: jobs.names,
    action: .cancel,
    scopes: jobs.scopes.map(\.mode)
  )}
}
extension Clockwork.Pipeline.Jobs.Play: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.affectJobs(
    cfg: cfg,
    pipeline: id,
    names: jobs.names,
    action: .play,
    scopes: []
  )}
}
extension Clockwork.Pipeline.Jobs.Retry: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.affectJobs(
    cfg: cfg,
    pipeline: id,
    names: jobs.names,
    action: .retry,
    scopes: jobs.scopes.map(\.mode)
  )}
}
extension Clockwork.Pipeline.Jobs.Scope {
  var mode: GitlabCi.JobScope {
    switch self {
    case .canceled: return .canceled
    case .created: return .created
    case .failed: return .failed
    case .manual: return .manual
    case .pending: return .pending
    case .running: return .running
    case .success: return .success
    }
  }
}
extension Clockwork.Pipeline.Trigger: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.triggerPipeline(cfg: cfg, ref: ref, context: context)
  }
}
extension Clockwork.Pipeline.Retry: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectPipeline(cfg: cfg, id: id, action: .retry)
  }
}
extension Clockwork.Pods.ResetSpecs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.restoreCocoapodsSpecs(cfg: cfg)
  }
}
extension Clockwork.Pods.UpdateSpecs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.updateCocoapodsSpecs(cfg: cfg)
  }
}
extension Clockwork.Report.Custom: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reporter.reportCustom(cfg: cfg, event: report.event, stdin: report.stdin.mode)
  }
}
extension Clockwork.Report.ReleaseThread: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reportCustom(cfg: cfg, event: report.event, stdin: report.stdin.mode)
  }
}
extension Clockwork.Report.ReviewThread: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.reportCustom(cfg: cfg, event: report.event, stdin: report.stdin.mode)
  }
}
extension Clockwork.Report.Stdin {
  var mode: Configuration.ReadStdin {
    switch self {
    case .ignore: return .ignore
    case .lines: return .lines
    case .json: return .json
    }
  }
}
extension Clockwork.Requisites.Erase: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.clearRequisites(cfg: cfg)
  }
}
extension Clockwork.Requisites.Import: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.installRequisite(cfg: cfg, requisites: requisites)
  }
}
extension Clockwork.Requisites.ImportPkcs12: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.installKeychain(cfg: cfg, requisites: requisites)
  }
}
extension Clockwork.Requisites.ImportProvisions: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.installProvisions(cfg: cfg, requisites: requisites)
  }
}
extension Clockwork.Requisites.ReportExpiring: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.reportExpiringRequisites(cfg: cfg, days: days)
  }
}
extension Clockwork.Review.Accept: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.acceptReview(cfg: cfg)
  }
}
extension Clockwork.Review.AddLabels: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.addReviewLabels(cfg: cfg, labels: labels)
  }
}
extension Clockwork.Review.Approve: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.approveReview(cfg: cfg, resolution: resolution.status)
  }
}
extension Clockwork.Review.Approve.Resolution {
  var status: Fusion.Approval.Status.Resolution {
    switch self {
    case .fragil: return .fragil
    case .advance: return .advance
    case .block: return .block
    }
  }
}
extension Clockwork.Review.Approver.Activate: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.updateApprover(cfg: cfg, gitlab: approver.gitlab, command: .activate)
  }
}
extension Clockwork.Review.Approver.Deactivate: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.updateApprover(cfg: cfg, gitlab: approver.gitlab, command: .deactivate)
  }
}
extension Clockwork.Review.Approver.Register: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.reviewer.updateApprover(
    cfg: cfg,
    gitlab: approver.gitlab,
    command: .register(slack)
  )}
}
extension Clockwork.Review.Approver.UnwatchAuthors: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.reviewer.updateApprover(
    cfg: cfg,
    gitlab: approver.gitlab,
    command: .watchAuthors(args)
  )}
}
extension Clockwork.Review.Approver.UnwatchTeams: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.reviewer.updateApprover(
    cfg: cfg,
    gitlab: approver.gitlab,
    command: .unwatchTeams(args)
  )}
}
extension Clockwork.Review.Approver.WatchAuthors: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.reviewer.updateApprover(
    cfg: cfg,
    gitlab: approver.gitlab,
    command: .watchAuthors(args)
  )}
}
extension Clockwork.Review.Approver.WatchTeams: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.reviewer.updateApprover(
    cfg: cfg,
    gitlab: approver.gitlab,
    command: .watchTeams(args)
  )}
}
extension Clockwork.Review.Clean: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.cleanReviews(cfg: cfg, remind: remind)
  }
}
extension Clockwork.Review.Dequeue: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.dequeueReview(cfg: cfg)
  }
}
extension Clockwork.Review.ExportIntegration: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.renderIntegration(cfg: cfg)
  }
}
extension Clockwork.Review.Own: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.ownReview(cfg: cfg)
  }
}
extension Clockwork.Review.ReserveBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reserveReviewBuild(cfg: cfg)
  }
}
extension Clockwork.Review.RemoveLabels: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.removeReviewLabels(cfg: cfg, labels: labels)
  }
}
extension Clockwork.Review.TriggerPipeline: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.createReviewPipeline(cfg: cfg)
  }
}
extension Clockwork.Review.Skip: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.skipReview(cfg: cfg, review: id)
  }
}
extension Clockwork.Review.StartReplication: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.startReplication(cfg: cfg)
  }
}
extension Clockwork.Review.StartIntegration: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.startIntegration(cfg: cfg, source: source, target: target, fork: fork)
  }
}
extension Clockwork.Review.Update: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.updateReview(cfg: cfg)
  }
}
extension Clockwork.Validate.ConflictMarkers: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateReviewConflictMarkers(cfg: cfg, base: base, json: validate.json)
  }
}
extension Clockwork.Validate.FileTaboos: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateFileTaboos(cfg: cfg, json: validate.json)
  }
}
extension Clockwork.Validate.UnownedCode: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateUnownedCode(cfg: cfg, json: validate.json)
  }
}
