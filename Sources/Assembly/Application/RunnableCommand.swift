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
      verbose: clockwork.logsubs,
      env: Assembler.environment
    )
    try Lossy(cfg)
      .map(run(cfg:))
      .reduceError(cfg, Assembler.reporter.report(cfg:error:))
      .reduce(cfg, Assembler.reporter.finish(cfg:success:))
      .get()
  }
}
extension Clockwork.ReportCustom: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reporter.reportCustom(cfg: cfg, event: event, stdin: stdin)
  }
}
extension Clockwork.ReportReviewCustom: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reporter.reportReviewCustom(cfg: cfg, event: event, stdin: stdin)
  }
}
extension Clockwork.CheckUnownedCode: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateUnownedCode(cfg: cfg)
  }
}
extension Clockwork.CheckFileTaboos: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateFileTaboos(cfg: cfg)
  }
}
extension Clockwork.CheckReviewConflictMarkers: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateReviewConflictMarkers(cfg: cfg, target: target)
  }
}
extension Clockwork.CheckReviewObsolete: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateReviewObsolete(cfg: cfg, target: target)
  }
}
extension Clockwork.CheckForbiddenCommits: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateForbiddenCommits(cfg: cfg)
  }
}
extension Clockwork.CheckResolutionAwardApproval: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.approver.checkAwardApproval(cfg: cfg, mode: .resolution, remind: remind)
  }
}
extension Clockwork.AddReviewLabels: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.addReviewLabels(cfg: cfg, labels: labels)
  }
}
extension Clockwork.ActivateAwardApprover: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.approver.updateUser(cfg: cfg, active: true, login: login)
  }
}
extension Clockwork.DeactivateAwardApprover: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.approver.updateUser(cfg: cfg, active: false, login: login)
  }
}
extension Clockwork.AcceptReview: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.merger.acceptReview(cfg: cfg)
  }
}
extension Clockwork.TriggerPipeline: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.triggerPipeline(cfg: cfg, ref: ref, context: context)
  }
}
extension Clockwork.CheckReplicationAwardApproval: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.approver.checkAwardApproval(cfg: cfg, mode: .replication, remind: remind)
  }
}
extension Clockwork.StartReplication: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.merger.startReplication(cfg: cfg)
  }
}
extension Clockwork.UpdateReview: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.merger.updateReview(cfg: cfg)
  }
}
extension Clockwork.CheckIntegrationAwardApproval: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.approver.checkAwardApproval(cfg: cfg, mode: .integration, remind: remind)
  }
}
extension Clockwork.ExportIntegrationTargets: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.merger.renderIntegration(cfg: cfg)
  }
}
extension Clockwork.StartIntegration: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.merger.startIntegration(cfg: cfg, source: source, target: target, fork: fork)
  }
}
extension Clockwork.ImportProvisions: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.installProvisions(cfg: cfg, requisites: requisites)
  }
}
extension Clockwork.ImportPkcs12: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.installKeychain(cfg: cfg, requisites: requisites)
  }
}
extension Clockwork.ImportRequisites: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.installRequisite(cfg: cfg, requisites: requisites)
  }
}
extension Clockwork.EraseRequisites: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.clearRequisites(cfg: cfg)
  }
}
extension Clockwork.ReportExpiringRequisites: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.reportExpiringRequisites(cfg: cfg, days: days)
  }
}
extension Clockwork.CreateDeployTag: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createDeployTag(cfg: cfg)
  }
}
extension Clockwork.CreateReleaseBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createReleaseBranch(cfg: cfg, product: product)
  }
}
extension Clockwork.CreateHotfixBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createHotfixBranch(cfg: cfg)
  }
}
extension Clockwork.CreateAccessoryBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createAccessoryBranch(cfg: cfg, suffix: suffix)
  }
}
extension Clockwork.ReserveParentReviewBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reserveReviewBuild(cfg: cfg)
  }
}
extension Clockwork.ReserveProtectedBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reserveProtectedBuild(cfg: cfg)
  }
}
extension Clockwork.ExportBuildContext: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.renderBuild(cfg: cfg)
  }
}
extension Clockwork.ExportCurrentVersions: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.renderVersions(cfg: cfg)
  }
}
extension Clockwork.CreateReviewPipeline: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.createReviewPipeline(cfg: cfg)
  }
}
extension Clockwork.PlayParentJob: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectParentJob(configuration: cfg, action: .play)
  }
}
extension Clockwork.CancelParentJob: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectParentJob(configuration: cfg, action: .cancel)
  }
}
extension Clockwork.RetryParentJob: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectParentJob(configuration: cfg, action: .retry)
  }
}
extension Clockwork.PlayNeighborJob: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectNeighborJob(configuration: cfg, name: name, action: .play)
  }
}
extension Clockwork.CancelNeighborJob: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectNeighborJob(configuration: cfg, name: name, action: .cancel)
  }
}
extension Clockwork.RetryNeighborJob: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectNeighborJob(configuration: cfg, name: name, action: .retry)
  }
}
extension Clockwork.ResetPodSpecs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.restoreCocoapodsSpecs(cfg: cfg)
  }
}
extension Clockwork.UpdatePodSpecs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.updateCocoapodsSpecs(cfg: cfg)
  }
}
