import Foundation
import Facility
extension Fusion {
  public enum Kind {
    case proposition(Proposition.Merge)
    case replication(Merge)
    case integration(Merge)
    public var merge: Merge? {
      switch self {
      case .proposition: return nil
      case .replication(let merge), .integration(let merge): return merge
      }
    }
    public var proposition: Bool {
      switch self {
      case .proposition: return true
      default: return false
      }
    }
    public var target: Git.Branch {
      switch self {
      case .proposition(let merge): return merge.target
      case .replication(let merge), .integration(let merge): return merge.target
      }
    }
    public var source: Git.Branch {
      switch self {
      case .proposition(let merge): return merge.source
      case .replication(let merge), .integration(let merge): return merge.source
      }
    }
  }
}
