import Foundation
import Facility
public struct Fusion {
  public var approval: Approval
  public var propositions: [String: Proposition]
  public var replication: Replication
  public var integration: Integration
  public var queue: Configuration.Asset
  public var createThread: Configuration.Template
  func createCommitMessage(kind: Kind) -> Configuration.Template {
    switch kind {
    case .proposition: return proposition.createCommitMessage
    case .replication: return replication.createCommitMessage
    case .integration: return integration.createCommitMessage
    }
  }
  public func makeKind(state: Json.GitlabReviewState, project: Json.GitlabProject) throws -> Kind {
    guard let merge = Merge.make(source: state.sourceBranch, project: project) else {
      let rules = proposition.rules.filter { $0.source.isMet(state.sourceBranch) }
      guard rules.count < 2
      else { throw Thrown("\(state.sourceBranch) matches multiple proposition rules") }
      return try .proposition(.init(
        target: .init(name: state.targetBranch),
        source: .init(name: state.sourceBranch),
        rule: rules.first
      ))
    }
    switch merge.prefix {
    case .replicate: return .replication(merge)
    case .integrate: return .integration(merge)
    }
  }
  public static func make(
    yaml: Yaml.Review
  ) throws -> Self { try .init(
    approval: .make(yaml: yaml.approval),
    proposition: .init(
      createCommitMessage: .make(yaml: yaml.proposition.createCommitMessage),
      rules: yaml.proposition.rules
        .map { yaml in try .init(
          title: .init(yaml: yaml.title),
          source: .init(yaml: yaml.source),
          task: yaml.task
            .map { try NSRegularExpression(pattern: $0, options: [.anchorsMatchLines]) }
        )}
    ),
    replication: .init(
      createCommitMessage: .make(yaml: yaml.replication.createCommitMessage)
    ),
    integration: .init(
      createCommitMessage: .make(yaml: yaml.integration.createCommitMessage),
      exportAvailableTargets: .make(yaml: yaml.integration.exportTargets)
    ),
    queue: .make(yaml: yaml.queue),
    createThread: .make(yaml: yaml.createThread)
  )}
}
