import Foundation
import Facility
import FacilityPure
extension ContextExclusive {
  func makeNotes(
    storage: Flow.Storage,
    release: Flow.Release,
    deploy: Flow.Deploy? = nil
  ) throws -> Flow.ReleaseNotes {
    let current = deploy.map(\.tag.ref).get(release.start.ref)
    let deploys: [Flow.Deploy]
    if let deploy = deploy {
      deploys = storage.deploys.values.filter(deploy.include(deploy:))
    } else {
      deploys = storage.deploys.values.filter(release.include(deploy:))
    }
    var commits: [Ctx.Git.Sha] = []
    commits += deploys.compactMap({ try? gitGetSha(ref: $0.tag.ref) })
    if deploy != nil { commits.append(release.start) }
    guard commits.isEmpty.not else { return .make(uniq: [], lack: []) }
    var trees: Set<String> = []
    var uniq: Set<Ctx.Git.Sha> = []

    for commit in try gitListCommits(
      in: [current],
      notIn: commits.map(\.ref),
      noMerges: true
    ) {
      if let patch = try gitPatchId(sha: commit) {
        guard trees.insert(patch).inserted else { continue }
      }
      uniq.insert(commit)
    }
    let lack = try gitListCommits(
      in: commits.map(\.ref),
      notIn: [current],
      noMerges: true
    )
    return try Flow.ReleaseNotes.make(
      uniq: uniq.map({ sha in try Flow.ReleaseNotes.Note.make(
        sha: sha,
        msg: gitCommitMessage(ref: sha.ref)
      )}),
      lack: lack.map({ sha in try Flow.ReleaseNotes.Note.make(
        sha: sha,
        msg: gitCommitMessage(ref: sha.ref)
      )})
    )
  }
}
