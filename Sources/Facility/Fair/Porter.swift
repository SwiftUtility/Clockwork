import Foundation
import Facility
import FacilityPure
//public final class Porter {
//  let execute: Try.Reply<Execute>
//  let resolveReviewQueue: Try.Reply<Fusion.Queue.Resolve>
//  let persistReviewQueue: Try.Reply<Fusion.Queue.Persist>
//  let logMessage: Act.Reply<LogMessage>
//  let worker: Worker
//  public init(
//    execute: @escaping Try.Reply<Execute>,
//    resolveReviewQueue: @escaping Try.Reply<Fusion.Queue.Resolve>,
//    persistReviewQueue: @escaping Try.Reply<Fusion.Queue.Persist>,
//    logMessage: @escaping Act.Reply<LogMessage>,
//    worker: Worker
//  ) {
//    self.execute = execute
//    self.resolveReviewQueue = resolveReviewQueue
//    self.persistReviewQueue = persistReviewQueue
//    self.logMessage = logMessage
//    self.worker = worker
//  }
//  public func enqueueReview(cfg: Configuration, fusion: Fusion) throws -> Bool {
//    var queue = try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
//    let ctx = try worker.resolveParentReview(cfg: cfg)
//    guard worker.isLastPipe(ctx: ctx) else { return false }
//    let result = queue.enqueue(review: ctx.review.iid, target: ctx.review.targetBranch)
//    if queue.isChanged { try persistReviewQueue(.init(
//      cfg: cfg,
//      pushUrl: ctx.gitlab.protected.get().push,
//      fusion: fusion,
//      reviewQueue: queue,
//      review: ctx.review,
//      queued: true
//    ))}
//    for notifiable in queue.notifiables {
//      try Execute.checkStatus(reply: execute(ctx.gitlab.postMrPipelines(review: notifiable).get()))
//    }
//    return result
//  }
//  public func dequeueReview(cfg: Configuration, fusion: Fusion) throws -> Bool {
//    let ctx = try worker.resolveParentReview(cfg: cfg)
//    guard worker.isLastPipe(ctx: ctx) else { return false }
//    var queue = try resolveReviewQueue(.init(cfg: cfg, fusion: fusion))
//    _ = queue.enqueue(review: ctx.review.iid, target: nil)
//    if queue.isChanged { try persistReviewQueue(.init(
//      cfg: cfg,
//      pushUrl: ctx.gitlab.protected.get().push,
//      fusion: fusion,
//      reviewQueue: queue,
//      review: ctx.review,
//      queued: true
//    ))}
//    for notifiable in queue.notifiables {
//      try Execute.checkStatus(reply: execute(ctx.gitlab.postMrPipelines(review: notifiable).get()))
//    }
//    return true
//  }
//}
