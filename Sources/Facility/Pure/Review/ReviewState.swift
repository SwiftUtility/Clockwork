import Foundation
import Facility
extension Review {
  public enum State {
    case infusion(Infusion)
    case confusion(Confusion)
    public enum Confusion {
      case undefinedInfusion
      case multipleInfusions([String])
      case sourceFormat
    }
    public enum Infusion {
      case merge(Merge)
      case squash(Squash)
      public var prefix: String {
        switch self {
        case .merge(let merge): return merge.prefix.rawValue
        case .squash(let squash): return squash.proposition.kind
        }
      }
      public var proposition: Bool {
        switch self {
        case .squash: return true
        default: return false
        }
      }
      public var target: Git.Branch {
        switch self {
        case .squash(let squash): return squash.target
        case .merge(let merge): return merge.target
        }
      }
      public var source: Git.Branch {
        switch self {
        case .squash(let squash): return squash.source
        case .merge(let merge): return merge.source
        }
      }
      public var createCommitMessage: Configuration.Template {
        switch self {
        case .merge(let merge): return merge.createCommitMessage
        case .squash(let squash): return squash.proposition.createCommitMessage
        }
      }
      public var merge: Merge? {
        guard case .merge(let merge) = self else { return nil }
        return merge
      }
      public struct Merge {
        public var target: Git.Branch
        public var source: Git.Branch
        public var fork: Git.Sha
        public var prefix: Prefix
        public var original: Git.Branch
        public var createCommitMessage: Configuration.Template
        public var autoApproveFork: Bool
      }
      public struct Squash {
        public var target: Git.Branch
        public var source: Git.Branch
        public var proposition: Fusion.Proposition
      }
      public enum Prefix: String {
        case replicate
        case integrate
      }
    }
  }
}
