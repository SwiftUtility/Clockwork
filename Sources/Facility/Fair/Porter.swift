import Foundation
import Facility
import FacilityPure
public final class Porter {
  let execute: Try.Reply<Execute>
  let resolveReviewQueue: Try.Reply<ReviewQueue.Resolve>
  let persistReviewQueue: Try.Reply<ReviewQueue.Persist>
  let logMessage: Act.Reply<LogMessage>
  let worker: Worker
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveReviewQueue: @escaping Try.Reply<ReviewQueue.Resolve>,
    persistReviewQueue: @escaping Try.Reply<ReviewQueue.Persist>,
    logMessage: @escaping Act.Reply<LogMessage>,
    worker: Worker
  ) {
    self.execute = execute
    self.resolveReviewQueue = resolveReviewQueue
    self.persistReviewQueue = persistReviewQueue
    self.logMessage = logMessage
    self.worker = worker
  }
  public func enqueueReview(cfg: Configuration) throws -> Bool {
    var queue = try resolveReviewQueue(.init(cfg: cfg))
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    let result = queue.enqueue(review: ctx.review.iid, target: ctx.review.targetBranch)
    if queue.isChanged { try persistReviewQueue(.init(
      cfg: cfg,
      pushUrl: ctx.gitlab.pushUrl.get(),
      reviewQueue: queue,
      review: ctx.review,
      queued: true
    ))}
    for notifiable in queue.notifiables {
      try Execute.checkStatus(reply: execute(ctx.gitlab.postMrPipelines(review: notifiable).get()))
    }
    return result
  }
  public func dequeueReview(cfg: Configuration) throws -> Bool {
    var queue = try resolveReviewQueue(.init(cfg: cfg))
    let ctx = try worker.resolveParentReview(cfg: cfg)
    guard worker.isLastPipe(ctx: ctx) else { return false }
    _ = queue.enqueue(review: ctx.review.iid, target: nil)
    if queue.isChanged { try persistReviewQueue(.init(
      cfg: cfg,
      pushUrl: ctx.gitlab.pushUrl.get(),
      reviewQueue: queue,
      review: ctx.review,
      queued: true
    ))}
    for notifiable in queue.notifiables {
      try Execute.checkStatus(reply: execute(ctx.gitlab.postMrPipelines(review: notifiable).get()))
    }
    return true
  }
}