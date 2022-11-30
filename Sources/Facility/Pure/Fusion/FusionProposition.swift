import Foundation
import Facility
extension Fusion {
  public struct Proposition {
    public var kind: String
    public var source: Criteria
    public var title: Criteria?
    public var task: NSRegularExpression?
    public struct Merge {
      public let target: Git.Branch
      public let source: Git.Branch
      public var proposition: Proposition?
    }
    public static func make(kind: String, yaml: Yaml.Review.Proposition) throws -> Self { try .init(
      kind: kind,
      source: .init(yaml: yaml.source),
      title: yaml.title.map(Criteria.init(yaml:)),
      task: yaml.task
        .map({ try NSRegularExpression(pattern: $0, options: [.anchorsMatchLines]) })
    )}
  }
}
