import Foundation
import Facility
import FacilityPure
extension UseCase {
  struct ConnectClean: ProtectedContractPerformer {
    func perform(exclusive ctx: ContextExclusive) throws -> Bool {
      <#code#>
    }
  }
}

//public func clean(query: Chat.Clean) -> Chat.Clean.Reply {
//  do { try perform(cfg: query.cfg, action: { storage, gitlab in
//    var updated: [String] = []
//    for review in storage.reviews.keys {
//      guard query.reviews.contains(review).not else { continue }
//      storage.reviews[review] = nil
//      updated.append(review)
//    }
//    guard updated.isEmpty.not else { return nil }
//    return query.cfg.createGitlabStorageCommitMessage(
//      user: nil,
//      reviews: updated,
//      gitlab: gitlab,
//      reason: .cleanReviews
//    )
//  })} catch {
//    logMessage(.make(error: error))
//  }
//  do { try clean(clean: query, chat: makeSlack(cfg: query.cfg)) }
//  catch { logMessage(.make(error: error)) }
//  do { try clean(clean: query, chat: makeRocket(cfg: query.cfg)) }
//  catch { logMessage(.make(error: error)) }
//}
