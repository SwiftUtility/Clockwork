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
extension Clockwork.AcceptReview: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.acceptReview(cfg: cfg)
  }
}
extension Clockwork.AddReviewLabels: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.addReviewLabels(cfg: cfg, labels: labels)
  }
}
extension Clockwork.ApproveReview: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.approveReview(cfg: cfg, resolution: resolution.status)
  }
}
extension Clockwork.ApproveReview.Resolution {
  var status: Yaml.Fusion.Approval.Status.Resolution {
    switch self {
    case .emergent: return .emergent
    case .fragil: return .fragil
    case .advance: return .advance
    case .block: return .block
    }
  }
}
extension Clockwork.CancelJobs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectJobs(
      configuration: cfg,
      pipeline: pipeline,
      names: names,
      action: .cancel
    )
  }
}
extension Clockwork.CheckConflictMarkers: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateReviewConflictMarkers(cfg: cfg, base: base, json: json)
  }
}
extension Clockwork.CheckFileTaboos: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateFileTaboos(cfg: cfg, json: json)
  }
}
extension Clockwork.CheckUnownedCode: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateUnownedCode(cfg: cfg, json: json)
  }
}
extension Clockwork.CreateAccessoryBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createAccessoryBranch(cfg: cfg, name: name)
  }
}
extension Clockwork.CreateDeployTag: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createDeployTag(cfg: cfg)
  }
}
extension Clockwork.CreateHotfixBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createHotfixBranch(cfg: cfg)
  }
}
extension Clockwork.CreateReleaseBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createReleaseBranch(cfg: cfg, product: product)
  }
}
extension Clockwork.DequeueReview: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.dequeueReview(cfg: cfg)
  }
}
extension Clockwork.EraseRequisites: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.clearRequisites(cfg: cfg)
  }
}
extension Clockwork.ExportBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.renderBuild(cfg: cfg)
  }
}
extension Clockwork.ExportIntegration: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.renderIntegration(cfg: cfg)
  }
}
extension Clockwork.ExportNextVersions: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.renderNextVersions(cfg: cfg)
  }
}
extension Clockwork.ImportRequisites: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.installRequisite(cfg: cfg, requisites: requisites)
  }
}
extension Clockwork.ImportPkcs12: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.installKeychain(cfg: cfg, requisites: requisites)
  }
}
extension Clockwork.ImportProvisions: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.installProvisions(cfg: cfg, requisites: requisites)
  }
}
extension Clockwork.OwnReview: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.ownReview(cfg: cfg)
  }
}
extension Clockwork.PlayJobs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectJobs(
      configuration: cfg,
      pipeline: pipeline,
      names: names,
      action: .play
    )
  }
}
extension Clockwork.RemindReviews: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.remindReviews(cfg: cfg)
  }
}
extension Clockwork.ReportCustom: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reporter.reportCustom(cfg: cfg, event: event, stdin: stdin.mode)
  }
}
extension Clockwork.ReportCustom.Stdin {
  var mode: Configuration.ReadStdin {
    switch self {
    case .ignore: return .ignore
    case .lines: return .lines
    case .json: return .json
    }
  }
}
extension Clockwork.ReportCustomRelease: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reportCustom(cfg: cfg, event: custom.event, stdin: custom.stdin.mode)
  }
}
extension Clockwork.ReportCustomReview: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.reportCustom(cfg: cfg, event: custom.event, stdin: custom.stdin.mode)
  }
}
extension Clockwork.ReportExpiringRequisites: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.reportExpiringRequisites(cfg: cfg, days: days)
  }
}
extension Clockwork.ReserveBranchBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reserveBranchBuild(cfg: cfg)
  }
}
extension Clockwork.ReserveReviewBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reserveReviewBuild(cfg: cfg)
  }
}
extension Clockwork.ResetPodSpecs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.restoreCocoapodsSpecs(cfg: cfg)
  }
}
extension Clockwork.RetryJobs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectJobs(
      configuration: cfg,
      pipeline: pipeline,
      names: names,
      action: .retry
    )
  }
}
extension Clockwork.RemoveReviewLabels: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.removeReviewLabels(cfg: cfg, labels: labels)
  }
}
extension Clockwork.TriggerPipeline: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.triggerPipeline(cfg: cfg, ref: ref, context: context)
  }
}
extension Clockwork.TriggerReviewPipeline: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.createReviewPipeline(cfg: cfg)
  }
}
extension Clockwork.StartReplication: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.startReplication(cfg: cfg)
  }
}
extension Clockwork.StartIntegration: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.startIntegration(cfg: cfg, source: source, target: target, fork: fork)
  }
}
extension Clockwork.UpdatePodSpecs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.updateCocoapodsSpecs(cfg: cfg)
  }
}
extension Clockwork.UpdateApprover: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.updateApprover(cfg: cfg, active: active, slack: slack, gitlab: gitlab)
  }
}
extension Clockwork.UpdateReview: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.updateReview(cfg: cfg)
  }
}
