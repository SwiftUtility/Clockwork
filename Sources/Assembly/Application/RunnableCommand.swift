import Foundation
import Facility
import FacilityPure
import FacilityFair
protocol RunnableCommand: ClockworkCommand {
  func run(cfg: Configuration) throws -> Bool
}
extension ClockworkCommand {
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
    guard let runnableCommand = self as? RunnableCommand
    else { throw MayDay("\(Self.self) not configured") }
    let cfg = try Assembler.configurator.configure(
      profile: clockwork.profile,
      env: Assembler.environment
    )
    defer { Assembler.reporter.sendReports(cfg: cfg) }
    do {
      guard try runnableCommand.run(cfg: cfg).not else { return }
    } catch {
      cfg.reportUnexpected(error: error)
      throw error
    }
    throw Thrown("Execution considered unsuccessful")
  }
}
extension Clockwork.Cocoapods.ResetSpecs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.restoreCocoapodsSpecs(cfg: cfg)
  }
}
extension Clockwork.Cocoapods.UpdateSpecs: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.requisitor.updateCocoapodsSpecs(cfg: cfg)
  }
}
extension Clockwork.Connect.Clean: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.clean(cfg: cfg)
  }
}
extension Clockwork.Connect.Signal: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.signal(
      cfg: cfg, event: event, stdin: stdin.mode, args: args
    )
  }
}
extension Clockwork.Flow.ChangeAccessoryVersion: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.changeAccessoryVersion(
      cfg: cfg, product: product, branch: branch, version: version
    )
  }
}
extension Clockwork.Flow.ChangeNextVersion: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.changeNextVersion(cfg: cfg, product: product, version: version)
  }
}
extension Clockwork.Flow.CreateAccessoryBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createAccessoryBranch(cfg: cfg, name: name, commit: sha)
  }
}
extension Clockwork.Flow.CreateDeployTag: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.createDeployTag(cfg: cfg)
  }
}
extension Clockwork.Flow.CreateStageTag: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.stageBuild(cfg: cfg, build: build, product: product)
  }
}
extension Clockwork.Flow.DeleteBranch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.deleteBranch(cfg: cfg, name: name)
  }
}
extension Clockwork.Flow.DeleteTag: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.deleteTag(cfg: cfg, name: name)
  }
}
extension Clockwork.Flow.ExportVersions: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.producer.renderVersions(
    cfg: cfg, product: product, stdin: stdin.mode, args: args
  )}
}
extension Clockwork.Flow.ReserveBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reserveBuild(cfg: cfg, review: false, product: product)
  }
}
extension Clockwork.Flow.StartHotfix: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.startHotfix(cfg: cfg, product: product, commit: commit, version: version)
  }
}
extension Clockwork.Flow.StartRelease: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.startRelease(cfg: cfg, product: product, commit: commit)
  }
}
extension Clockwork.Gitlab.Artifacts.LoadFile: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.loadArtifact(cfg: cfg, job: artifacts.job, path: path)
  }
}
extension Clockwork.Gitlab.Jobs.Cancel: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.affectJobs(
    cfg: cfg,
    pipeline: jobs.pipeline,
    names: names,
    action: .cancel,
    scopes: jobs.scopes.map(\.mode)
  )}
}
extension Clockwork.Gitlab.Jobs.Play: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.affectJobs(
    cfg: cfg,
    pipeline: jobs.pipeline,
    names: names,
    action: .play,
    scopes: []
  )}
}
extension Clockwork.Gitlab.Jobs.Retry: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.affectJobs(
    cfg: cfg,
    pipeline: jobs.pipeline,
    names: names,
    action: .retry,
    scopes: jobs.scopes.map(\.mode)
  )}
}
extension Clockwork.Gitlab.Jobs.Scope {
  var mode: Gitlab.JobScope {
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
extension Clockwork.Gitlab.Pipeline.Cancel: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectPipeline(cfg: cfg, id: pipeline.id, action: .cancel)
  }
}
extension Clockwork.Gitlab.Pipeline.Delete: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectPipeline(cfg: cfg, id: pipeline.id, action: .delete)
  }
}
extension Clockwork.Gitlab.Pipeline.Retry: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.affectPipeline(cfg: cfg, id: pipeline.id, action: .retry)
  }
}
extension Clockwork.Gitlab.TriggerPipeline: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.triggerPipeline(cfg: cfg, ref: ref, context: context)
  }
}
extension Clockwork.Gitlab.TriggerReviewPipeline: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.triggerReview(cfg: cfg, iid: review)
  }
}
extension Clockwork.Gitlab.User.Activate: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.updateUser(cfg: cfg, login: user.login, command: .activate)
  }
}
extension Clockwork.Gitlab.User.Deactivate: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.updateUser(cfg: cfg, login: user.login, command: .deactivate)
  }
}
extension Clockwork.Gitlab.User.Register: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.updateUser(
    cfg: cfg,
    login: user.login,
    command: .register([
      .slack: slack,
      .rocket: rocket,
    ])
  )}
}
extension Clockwork.Gitlab.User.UnwatchAuthors: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.updateUser(
    cfg: cfg,
    login: user.login,
    command: .watchAuthors(args)
  )}
}
extension Clockwork.Gitlab.User.UnwatchTeams: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.updateUser(
    cfg: cfg,
    login: user.login,
    command: .unwatchTeams(args)
  )}
}
extension Clockwork.Gitlab.User.WatchAuthors: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.updateUser(
    cfg: cfg,
    login: user.login,
    command: .watchAuthors(args)
  )}
}
extension Clockwork.Gitlab.User.WatchTeams: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool { try Assembler.mediator.updateUser(
    cfg: cfg,
    login: user.login,
    command: .watchTeams(args)
  )}
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
extension Clockwork.Render: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.render(
      cfg: cfg, template: template, stdin: stdin.mode, args: args
    )
  }
}
extension Clockwork.Review.Accept: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.acceptReview(cfg: cfg)
  }
}
extension Clockwork.Review.AddLabels: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.addReviewLabels(cfg: cfg, labels: labels)
  }
}
extension Clockwork.Review.Approve: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.approveReview(cfg: cfg, advance: advance)
  }
}
extension Clockwork.Review.Dequeue: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.dequeueReview(cfg: cfg, iid: iid)
  }
}
extension Clockwork.Review.Enqueue: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.enqueueReview(cfg: cfg)
  }
}
extension Clockwork.Review.ExportTargets: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.renderTargets(cfg: cfg, stdin: stdin.mode, args: args)
  }
}
extension Clockwork.Review.List: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.listReviews(cfg: cfg, user: user)
  }
}
extension Clockwork.Review.Own: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.ownReview(cfg: cfg, user: user, iid: iid)
  }
}
extension Clockwork.Review.Patch: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.patchReview(cfg: cfg, skip: skip, message: message)
  }
}
extension Clockwork.Review.Rebase: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.rebaseReview(cfg: cfg, iid: iid)
  }
}
extension Clockwork.Review.Remind: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.remindReview(cfg: cfg, iid: iid)
  }
}
extension Clockwork.Review.RemoveLabels: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.removeReviewLabels(cfg: cfg, labels: labels)
  }
}
extension Clockwork.Review.ReserveBuild: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.producer.reserveBuild(cfg: cfg, review: true, product: product)
  }
}
extension Clockwork.Review.TriggerPipeline: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.mediator.createReviewPipeline(cfg: cfg)
  }
}
extension Clockwork.Review.Skip: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.skipReview(cfg: cfg, iid: iid)
  }
}
extension Clockwork.Review.StartDuplication: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.startFusion(
      cfg: cfg, prefix: .duplicate, source: source, target: target, fork: fork
    )
  }
}
extension Clockwork.Review.StartIntegration: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.startFusion(
      cfg: cfg, prefix: .integrate, source: source, target: target, fork: fork
    )
  }
}
extension Clockwork.Review.StartPropogation: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.startFusion(
      cfg: cfg, prefix: .propogate, source: source, target: target, fork: fork
    )
  }
}
extension Clockwork.Review.StartReplication: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.startFusion(
      cfg: cfg, prefix: .replicate, source: source, target: target, fork: fork
    )
  }
}
extension Clockwork.Review.Unown: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.unownReview(cfg: cfg, user: user, iid: iid)
  }
}
extension Clockwork.Review.Update: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.reviewer.updateReviews(cfg: cfg)
  }
}
extension Clockwork.Validate.ConflictMarkers: RunnableCommand {
  func run(cfg: Configuration) throws -> Bool {
    try Assembler.validator.validateReviewConflictMarkers(
      cfg: cfg,
      target: target,
      json: validate.json
    )
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
extension Common.Stdin {
  var mode: Configuration.ParseStdin {
    switch self {
    case .ignore: return .ignore
    case .lines: return .lines
    case .json: return .json
    case .yaml: return .yaml
    }
  }
}
