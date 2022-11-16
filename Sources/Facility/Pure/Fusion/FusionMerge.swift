import Foundation
import Facility
extension Fusion {
  public struct Merge {
    public let fork: Git.Sha
    public let prefix: Prefix
    public let subject: Git.Branch
    public let target: Git.Branch
    public let source: Git.Branch
    public static func makeIntegration(
      fork: Git.Sha,
      subject: Git.Branch,
      target: Git.Branch
    ) throws -> Self {
      let components = [Prefix.integrate.rawValue, target.name, subject.name, fork.value]
      return try .init(
        fork: fork,
        prefix: .integrate,
        subject: subject,
        target: target,
        source: .init(name: components.joined(separator: "/-/"))
      )
    }
    public static func makeReplication(
      fork: Git.Sha,
      subject: Git.Branch,
      project: Json.GitlabProject
    ) throws -> Self {
      let components = [Prefix.replicate.rawValue, subject.name, fork.value]
      return try .init(
        fork: fork,
        prefix: .replicate,
        subject: subject,
        target: .init(name: project.defaultBranch),
        source: .init(name: components.joined(separator: "/-/"))
      )
    }
    public static func make(source: String, project: Json.GitlabProject) -> Self? {
      let components = source.components(separatedBy: "/-/")
      guard let prefix = components.first.flatMap(Prefix.init(rawValue:)) else { return nil }
      switch prefix {
      case .replicate:
        guard components.count == 3 else { return nil }
        return try? .init(
          fork: .make(value: components[2]),
          prefix: prefix,
          subject: .init(name: components[1]),
          target: .init(name: project.defaultBranch),
          source: .init(name: source)
        )
      case .integrate:
        guard components.count == 4 else { return nil }
        return try? .init(
          fork: .make(value: components[3]),
          prefix: prefix,
          subject: .init(name: components[2]),
          target: .init(name: components[1]),
          source: .init(name: source)
        )
      }
    }
    public enum Prefix: String {
      case replicate
      case integrate
    }
  }
}
