import Foundation
import Facility
public struct Fusion {
  public var approval: Approval
  public var propositions: [String: Proposition]
  public var replication: Replication
  public var integration: Integration
  public var queue: Configuration.Asset
  public var createCommitMessage: Configuration.Template
  public static func make(
    yaml: Yaml.Review
  ) throws -> Self { try .init(
    approval: .make(yaml: yaml.approval),
    propositions: yaml.propositions
      .map(Proposition.make(kind:yaml:))
      .reduce(into: [:], { $0[$1.kind] = $1 }),
    replication: .init(
      createCommitMessage: .make(yaml: yaml.replication.createCommitMessage),
      autoApproveFork: yaml.replication.autoApproveFork.get(false)
    ),
    integration: .init(
      createCommitMessage: .make(yaml: yaml.integration.createCommitMessage),
      exportAvailableTargets: .make(yaml: yaml.integration.exportTargets),
      autoApproveFork: yaml.replication.autoApproveFork.get(false)
    ),
    queue: .make(yaml: yaml.queue),
    createCommitMessage: .make(yaml: yaml.createCommitMessage)
  )}
  public func makeReviewState(
    review: Json.GitlabReviewState,
    project: Json.GitlabProject
  ) throws -> Review.State {
    typealias Infusion = Review.State.Infusion
    var infusions: [Infusion] = []
    let source = try Git.Branch(name: review.sourceBranch)
    let target = try Git.Branch(name: review.targetBranch)
    let components = source.name.components(separatedBy: "/-/")
    if let prefix = components.first.flatMap(Infusion.Prefix.init(rawValue:)) {
      switch prefix {
      case .replicate:
        guard components.count == 3, let infusion = try? Infusion.merge(.init(
          target: target,
          source: source,
          fork: .make(value: components[2]),
          prefix: prefix,
          original: .init(name: components[1]),
          createCommitMessage: replication.createCommitMessage,
          autoApproveFork: replication.autoApproveFork
        )) else { return .confusion(.sourceFormat) }
        infusions.append(infusion)
      case .integrate:
        guard components.count == 4, let infusion = try? Infusion.merge(.init(
          target: target,
          source: source,
          fork: .make(value: components[3]),
          prefix: prefix,
          original: .init(name: components[2]),
          createCommitMessage: integration.createCommitMessage,
          autoApproveFork: replication.autoApproveFork
        )) else { return .confusion(.sourceFormat) }
        infusions.append(infusion)
      }
    }
    for proposition in propositions.values {
      guard proposition.source.isMet(source.name) else { continue }
      infusions.append(.squash(.init(
        target: target,
        source: source,
        proposition: proposition
      )))
    }
    guard infusions.count < 2
    else { return .confusion(.multipleInfusions(infusions.map(\.prefix))) }
    guard let infusion = infusions.first else { return .confusion(.undefinedInfusion) }
    return .infusion(infusion)
  }
  public func makeIntegration(
    fork: Git.Sha,
    original: Git.Branch,
    target: Git.Branch
  ) throws -> Review.State.Infusion.Merge {
    let components = [
      Review.State.Infusion.Prefix.integrate.rawValue,
      target.name,
      original.name,
      fork.value,
    ]
    return try .init(
      target: target,
      source: .init(name: components.joined(separator: "/-/")),
      fork: fork,
      prefix: .integrate,
      original: original,
      createCommitMessage: integration.createCommitMessage,
      autoApproveFork: integration.autoApproveFork
    )
  }
  public func makeReplication(
    fork: Git.Sha,
    original: Git.Branch,
    project: Json.GitlabProject
  ) throws -> Review.State.Infusion.Merge {
    let components = [
      Review.State.Infusion.Prefix.replicate.rawValue,
      original.name,
      fork.value,
    ]
    return try .init(
      target: .init(name: project.defaultBranch),
      source: .init(name: components.joined(separator: "/-/")),
      fork: fork,
      prefix: .replicate,
      original: original,
      createCommitMessage: replication.createCommitMessage,
      autoApproveFork: replication.autoApproveFork
    )
  }
}
