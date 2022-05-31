import Foundation
import Facility
import FacilityAutomates
extension Gitlab {
  public struct TriggerTargetPipeline: Query {
    public var context: [String]
    public var cfg: Configuration
    public init(context: [String], cfg: Configuration) {
      self.context = context
      self.cfg = cfg
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
  public struct AddLabels: Query {
    public var labels: [String]
    public var cfg: Configuration
    public init(labels: [String], cfg: Configuration) {
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
  public struct CreateIntegrationJobs: Query {
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
