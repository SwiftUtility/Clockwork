import Foundation
import Facility
import FacilityPure
public extension ContextGitlab {
  func contractReview(_ payload: ContractPayload) throws -> Bool {
    guard case .value = gitlab.current.review else { throw Thrown("Not review job") }
    try triggerPipeline(ref: gitlab.cfg.contract.ref.value, variables: Contract.GitlabInfo.pack(
      job: gitlab.current.id,
      version: repo.profile.version,
      payload: payload,
      encoder: sh.rawEncoder
    ))
    return true
  }
  func contractProtected(_ payload: ContractPayload) throws -> Bool {
    let protected = try gitlab.protected.get()
    try createPipeline(protected: protected, variables: Contract.GitlabInfo.pack(
      job: gitlab.current.id,
      version: repo.profile.version,
      payload: payload,
      encoder: sh.rawEncoder
    ))
    return true
  }
  func contract(_ payload: ContractPayload) throws -> Bool {
    let variables = try Contract.GitlabInfo.pack(
      job: gitlab.current.id,
      version: repo.profile.version,
      payload: payload,
      encoder: sh.rawEncoder
    )
    if let protected = try? gitlab.protected.get() {
      try createPipeline(protected: protected, variables: variables)
    } else if case .value = gitlab.current.review {
      try triggerPipeline(ref: gitlab.cfg.contract.ref.value, variables: variables)
    } else {
      throw Thrown("Not either review or protected ref job")
    }
    return true
  }
  func triggerProtected(args: [String]) throws -> Bool {
    let protected = try gitlab.protected.get()
    var variables: [Contract.GitlabInfo.Variable] = []
    for variable in args {
      guard let index = variable.firstIndex(of: "=")
      else { throw Thrown("Wrong argument format \(variable)") }
      variables.append(.make(
        key: .init(variable[variable.startIndex..<index]),
        value: .init(variable[variable.index(after: index)..<variable.endIndex])
      ))
    }
    try triggerPipeline(ref: protected.proj.defaultBranch, variables: variables)
    return true
  }
  func exportFusion(fork: String, source: String) throws -> Bool {
    let fork = try Ctx.Git.Sha.make(value: fork)
    let source = try Ctx.Git.Branch.make(name: source)
    var targets = try gitlab.protected
      .map(listBranches(protected:))
      .get()
      .filter(\.protected)
      .map(\.name)
      .map(Ctx.Git.Branch.make(name:))
      .filter({ (try? repo.git.mergeBase(sh: sh, $0.remote, fork.ref)) != nil })
      .reduce(into: Set(), { $0.insert($1) })
    targets.remove(source)
    guard targets.isEmpty.not else { return false }
    let integrate = targets.sorted()
    let propogate = try integrate
      .filter({ try repo.git.check(sh: sh, child: $0.remote, parent: fork.ref) })
    let duplicate = try repo.git.listParents(sh: sh, ref: fork.ref).count == 1
    try sh.stdout(sh.rawEncoder.encode(Json.FusionTargets.make(
      fork: fork,
      source: source,
      integrate: integrate,
      duplicate: duplicate,
      propogate: propogate
    )))
    return true
  }
}
