import Foundation
import Facility
public struct Fusion {
  public var approval: Approval
  public var propositions: [String: Proposition]
  public var replication: Replication
  public var integration: Integration
  public var queue: Configuration.Asset
  public var createCommitMessage: Configuration.Template
  public var exportMergeTargets: Configuration.Template
  public static func make(
    yaml: Yaml.Review
  ) throws -> Self { try .init(
    approval: .make(yaml: yaml.approval),
    propositions: yaml.propositions
      .map(Proposition.make(kind:yaml:))
      .reduce(into: [:], { $0[$1.kind] = $1 }),
    replication: .init(
      autoApproveFork: yaml.replication.autoApproveFork.get(false),
      allowOrphaned: yaml.replication.allowOrphaned.get(false)
    ),
    integration: .init(
      autoApproveFork: yaml.integration.autoApproveFork.get(false),
      allowOrphaned: yaml.integration.allowOrphaned.get(false)
    ),
    queue: .make(yaml: yaml.queue),
    createCommitMessage: .make(yaml: yaml.createCommitMessage),
    exportMergeTargets: .make(yaml: yaml.exportMergeTargets)
  )}
  public func makeReviewState(
    status: Approval.Status,
    review: Json.GitlabReviewState,
    project: Json.GitlabProject
  ) throws -> Review.State {
    typealias Infusion = Review.State.Infusion
    var infusions: [Infusion] = []
    let source = try Git.Branch.make(name: review.sourceBranch)
    let target = try Git.Branch.make(name: review.targetBranch)
    if let replicate = status.replicate {
      let components = source.name.components(separatedBy: "/")
      guard
        components.count == 2,
        components[0] == Infusion.Prefix.replicate.rawValue,
        let fork = try? Git.Sha.make(value: components[1])
      else { return .confusion(.sourceFormat) }
      infusions.append(.merge(.init(
        target: target,
        source: source,
        fork: fork,
        prefix: .replicate,
        original: replicate,
        autoApproveFork: replication.autoApproveFork,
        allowOrphaned: replication.allowOrphaned
      )))
    }
    if let integrate = status.integrate {
      let components = source.name.components(separatedBy: "/")
      guard
        components.count > 2,
        components[0] == Infusion.Prefix.integrate.rawValue,
        let fork = try? Git.Sha.make(value: components[1]),
        let target = try? Git.Branch.make(
          name: source.name.dropPrefix("\(components[0])/\(fork.value)/")
        )
      else { return .confusion(.sourceFormat) }
      infusions.append(.merge(.init(
        target: target,
        source: source,
        fork: fork,
        prefix: .integrate,
        original: integrate,
        autoApproveFork: integration.autoApproveFork,
        allowOrphaned: integration.allowOrphaned
      )))
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
  ) throws -> Review.State.Infusion.Merge { try .init(
    target: target,
    source: .make(
      name: [Review.State.Infusion.Prefix.integrate.rawValue, fork.value, target.name]
        .joined(separator: "/")
    ),
    fork: fork,
    prefix: .integrate,
    original: original,
    autoApproveFork: integration.autoApproveFork,
    allowOrphaned: integration.allowOrphaned
  )}
  public func makeReplication(
    fork: Git.Sha,
    original: Git.Branch,
    project: Json.GitlabProject
  ) throws -> Review.State.Infusion.Merge { try .init(
    target: .make(name: project.defaultBranch),
    source: .make(
      name: [Review.State.Infusion.Prefix.replicate.rawValue, fork.value]
        .joined(separator: "/")
    ),
    fork: fork,
    prefix: .replicate,
    original: original,
    autoApproveFork: replication.autoApproveFork,
    allowOrphaned: replication.allowOrphaned
  )}
}
