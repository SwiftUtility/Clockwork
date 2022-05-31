import Foundation
import Facility
public struct Git {
  public var root: Path.Absolute
  public var lfs: Bool = false
  public var author: String?
  public var head: String?
  public init(root: Path.Absolute) throws {
    self.root = root
  }
  public struct File {
    public var ref: Ref
    public var path: Path.Relative
    public init(ref: Ref, path: Path.Relative) {
      self.ref = ref
      self.path = path
    }
    public init(local: String) throws {
      self.path = try .init(path: local)
      self.ref = .head
    }
  }
  public struct Dir {
    public var ref: Ref
    public var path: Path.Relative
    public init(ref: Ref, path: Path.Relative) {
      self.ref = ref
      self.path = path
    }
  }
  public struct Ref {
    public let value: String
    public var tree: Tree { .init(ref: self) }
    public static func make(parent number: Int, ref: Self) throws -> Self {
      guard number > 0 else { throw MayDay("commit parent must be > 0") }
      return .init(value: "\(ref.value)^\(number)")
    }
    public static var head: Self { .init(value: "HEAD") }
    public static func make(sha: Sha) -> Self {
      return .init(value: sha.ref)
    }
    public static func make(tag: String) throws -> Self {
      guard !tag.isEmpty else { throw Thrown("tag is empty") }
      return .init(value: "refs/tags/\(tag)")
    }
    public static func make(remote branch: Branch) -> Self {
      return .init(value: "refs/remotes/origin/\(branch.name)")
    }
    public static func make(local branch: Branch) -> Self {
      return .init(value: "refs/heads/\(branch.name)")
    }
  }
  public struct Sha {
    public let ref: String
    public init(ref: String) throws {
      guard ref.count == 40, ref.trimmingCharacters(in: .hexadecimalDigits).isEmpty else {
        throw Thrown("not sha: \(ref)")
      }
      self.ref = ref
    }
  }
  public struct Tree {
    public let value: String
    public init(ref: Ref) {
      self.value = "\(ref.value)^{tree}"
    }
    public init(sha: String) throws {
      self.value = try Sha(ref: sha).ref
    }
  }
  public struct Branch {
    public let name: String
    public init(name: String) throws {
      guard
        !name.isEmpty,
        !name.hasPrefix("/"),
        !name.hasSuffix("/"),
        !name.contains(" ")
      else { throw Thrown("invalid branch name") }
      self.name = name
    }
  }
}
