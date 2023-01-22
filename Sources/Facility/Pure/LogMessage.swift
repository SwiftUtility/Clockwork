import Foundation
import Facility
public struct LogMessage: Query {
  public var message: String
  public init(message: String) { self.message = message }
  public static var pipelineOutdated: Self { .init(message: "Pipeline is not the latest") }
  public static var reviewObsolete: Self { .init(message: "Pipeline configuration is obsolete") }
  public static var reviewClosed: Self { .init(message: "Review is closed") }
  public typealias Reply = Void
}
