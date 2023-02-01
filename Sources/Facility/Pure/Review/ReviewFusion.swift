import Foundation
import Facility
extension Review {
  public enum Fusion {
    case propose(Propose)
    case replicate(Replicate)
    case integrate(Integrate)
    case duplicate(Duplicate)
    case propogate(Propogate)
    public var proposition: Bool {
      if case .propose = self { return true } else { return false }
    }
    public var replication: Bool {
      if case .replicate = self { return true } else { return false }
    }
    public var integration: Bool {
      if case .integrate = self { return true } else { return false }
    }
    public var duplication: Bool {
      if case .duplicate = self { return true } else { return false }
    }
    public var propogation: Bool {
      if case .propogate = self { return true } else { return false }
    }
    public var kind: String {
      switch self {
      case .propose(let propose): return propose.proposition.name
      case .replicate: return Prefix.replicate.rawValue
      case .integrate: return Prefix.integrate.rawValue
      case .duplicate: return Prefix.duplicate.rawValue
      case .propogate: return Prefix.propogate.rawValue
      }
    }
    public var target: Git.Branch {
      switch self {
      case .propose(let propose): return propose.target
      case .replicate(let replicate): return replicate.target
      case .integrate(let integrate): return integrate.target
      case .duplicate(let duplicate): return duplicate.target
      case .propogate(let propogate): return propogate.target
      }
    }
    public var source: Git.Branch {
      switch self {
      case .propose(let propose): return propose.source
      case .replicate(let replicate): return replicate.source
      case .integrate(let integrate): return integrate.source
      case .duplicate(let duplicate): return duplicate.source
      case .propogate(let propogate): return propogate.source
      }
    }
    public var fork: Git.Sha? {
      switch self {
      case .propose: return nil
      case .replicate(let replicate): return replicate.fork
      case .integrate(let integrate): return integrate.fork
      case .duplicate(let duplicate): return duplicate.fork
      case .propogate(let propogate): return propogate.fork
      }
    }
    public var original: Git.Branch? {
      switch self {
      case .propose: return nil
      case .replicate(let replicate): return replicate.original
      case .integrate(let integrate): return integrate.original
      case .duplicate(let duplicate): return duplicate.original
      case .propogate(let propogate): return propogate.original
      }
    }
    public var allowOrphaned: Bool {
      switch self {
      case .propose: return false
      case .replicate(let replicate): return replicate.replication.allowOrphaned
      case .integrate(let integrate): return integrate.integration.allowOrphaned
      case .duplicate(let duplicate): return duplicate.duplication.allowOrphaned
      case .propogate(let propogate): return propogate.propogation.allowOrphaned
      }
    }
    public var autoApproveFork: Git.Sha? {
      switch self {
      case .propose: return nil
      case .replicate(let replicate):
        return replicate.replication.autoApproveFork.then(replicate.fork)
      case .integrate(let integrate):
        return integrate.integration.autoApproveFork.then(integrate.fork)
      case .duplicate: return nil
      case .propogate(let propogate):
        return propogate.propogation.autoApproveFork.then(propogate.fork)
      }
    }
    public var selfApproval: Bool {
      if case .propose = self { return false } else { return true }
    }
    public var diffApproval: Bool {
      switch self {
      case .propose: return true
      case .replicate: return true
      case .integrate: return true
      case .duplicate: return false
      case .propogate: return false
      }
    }
    public var authorshipApproval: Bool {
      switch self {
      case .propose: return true
      case .replicate: return false
      case .integrate: return false
      case .duplicate: return false
      case .propogate: return false
      }
    }
    public var randomApproval: Bool {
      switch self {
      case .propose: return true
      case .replicate: return false
      case .integrate: return false
      case .duplicate: return false
      case .propogate: return false
      }
    }
    public struct Propose {
      public var source: Git.Branch
      public var target: Git.Branch
      public var proposition: Proposition
    }
    public struct Replicate {
      public var fork: Git.Sha
      public var source: Git.Branch
      public var target: Git.Branch
      public var original: Git.Branch
      public var replication: Replication
    }
    public struct Integrate {
      public var fork: Git.Sha
      public var source: Git.Branch
      public var target: Git.Branch
      public var original: Git.Branch
      public var integration: Integration
    }
    public struct Duplicate {
      public var fork: Git.Sha
      public var source: Git.Branch
      public var target: Git.Branch
      public var original: Git.Branch
      public var duplication: Duplication
    }
    public struct Propogate {
      public var fork: Git.Sha
      public var source: Git.Branch
      public var target: Git.Branch
      public var original: Git.Branch
      public var propogation: Propogation
    }
    public enum GitCheck {
      case extraCommits(branches: [Git.Branch], exclude: [Git.Ref], head: Git.Sha)
      case notCherry(fork: Git.Sha, head: Git.Sha, target: Git.Branch)
      case notForward(fork: Git.Sha, head: Git.Sha, target: Git.Branch)
      case forkInTarget(fork: Git.Sha, target: Git.Branch)
      case forkNotInOriginal(fork: Git.Sha, original: Git.Branch)
      case forkNotInSource(fork: Git.Sha, head: Git.Sha)
      case forkParentNotInTarget(fork: Git.Sha, target: Git.Branch)
    }
    public struct ApprovesCheck {
      public var head: Git.Sha
      public var target: Git.Branch
      public var fork: Git.Sha?
      public var diff: [String] = []
      public var changes: [Git.Sha: [String]] = [:]
      public var childs: [Git.Sha: Set<Git.Sha>] = [:]
    }
    public enum Prefix: String {
      case replicate
      case integrate
      case duplicate
      case propogate
      public func makeFusion(
        review: Review,
        fork: Git.Sha,
        target: Git.Branch,
        original: Git.Branch
      ) throws -> Fusion {
        switch self {
        case .replicate: return try .replicate(.init(
          fork: fork,
          source: .make(name: makeSource(target: target, fork: fork)),
          target: target,
          original: original,
          replication: review.replication
        ))
        case .integrate: return try .integrate(.init(
          fork: fork,
          source: .make(name: makeSource(target: target, fork: fork)),
          target: target,
          original: original,
          integration: review.integration
        ))
        case .duplicate: return try .duplicate(.init(
          fork: fork,
          source: .make(name: makeSource(target: target, fork: fork)),
          target: target,
          original: original,
          duplication: review.duplication
        ))
        case .propogate: return try .propogate(.init(
          fork: fork,
          source: .make(name: makeSource(target: target, fork: fork)),
          target: target,
          original: original,
          propogation: review.propogation
        ))
        }
      }
      func makeSource(target: Git.Branch, fork: Git.Sha) -> String {
        "\(rawValue)/\(target.name)/\(fork.value)"
      }
    }
  }
}
