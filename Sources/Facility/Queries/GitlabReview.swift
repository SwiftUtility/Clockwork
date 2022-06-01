import Foundation
import Facility
import FacilityAutomates
extension Gitlab {
  public struct TriggerPipeline: Query {
    public var cfg: Configuration
    public var ref: String
    public var context: [String]
    public init(cfg: Configuration, ref: String, context: [String]) {
      self.cfg = cfg
      self.ref = ref
      self.context = context
    }
    public typealias Reply = Bool
  }
  public struct CheckAwardApproval: Query {
    public var cfg: Configuration
    public var mode: Mode
    public init(cfg: Configuration, mode: Mode) {
      self.cfg = cfg
      self.mode = mode
    }
    public enum Mode {
      case review
      case replication
      case integration
    }
    public typealias Reply = Bool
  }
  public struct AddReviewLabels: Query {
    public var cfg: Configuration
    public var labels: [String]
    public init(cfg: Configuration, labels: [String]) {
      self.labels = labels
      self.cfg = cfg
    }
    public typealias Reply = Bool
  }
  public struct AcceptReview: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = Bool
  }
  public struct PerformReplication: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = Bool
  }
  public struct ApproveReplication: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = Bool
  }
  public struct PerformIntegration: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = Bool
  }
  public struct GenerateIntegrationJobs: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = Bool
  }
  public struct ApproveIntegration: Query {
    public var cfg: Configuration
    public init(cfg: Configuration) {
      self.cfg = cfg
    }
    public typealias Reply = Bool
  }
}
