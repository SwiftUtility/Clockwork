import Foundation
import Facility
import FacilityQueries
import FacilityAutomates
public struct Requisitor {
  let execute: Try.Reply<Execute>
  let resolveAbsolutePath: Try.Reply<ResolveAbsolutePath>
  let resolveRequisition: Try.Reply<ResolveRequisition>
  let plistDecoder: PropertyListDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    resolveAbsolutePath: @escaping Try.Reply<ResolveAbsolutePath>,
    resolveRequisition: @escaping Try.Reply<ResolveRequisition>,
    plistDecoder: PropertyListDecoder
  ) {
    self.execute = execute
    self.resolveAbsolutePath = resolveAbsolutePath
    self.resolveRequisition = resolveRequisition
    self.plistDecoder = plistDecoder
  }
  public func importProvisions(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    let requisition = try resolveRequisition(.init(cfg: cfg))
    try requisites
      .flatMap { try getProvisions(git: cfg.git, requisition: requisition, requisite: $0)}
      .forEach { try install(cfg: cfg, provision: $0) }
    return true
  }
  public func importKeychains(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func importRequisites(
    cfg: Configuration,
    requisites: [String]
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  public func reportExpiringRequisites(
    cfg: Configuration,
    days: UInt
  ) throws -> Bool {
    throw MayDay("Not implemented")
  }
  func getProvisions(
    git: Git,
    requisition: Requisition,
    requisite: String
  ) throws -> [Git.File] {
    let dir = try requisition.provisions[requisite]
      .or { throw Thrown("No \(requisite) in provisions") }
    return try Id(dir)
      .map(git.listTreeTrackedFiles(dir:))
      .map(execute)
      .map(String.make(utf8:))
      .get()
      .components(separatedBy: .newlines)
      .map(Path.Relative.init(value:))
      .map { .init(ref: dir.ref, path: $0) }
  }
  func install(cfg: Configuration, provision: Git.File) throws {
    let requisition = try resolveRequisition(.init(cfg: cfg))
    let temp = try Id(cfg.systemTempFile)
      .map(execute)
      .map(String.make(utf8:))
      .map(Path.Absolute.init(value:))
    _ = try Id(provision)
      .map(cfg.git.cat(file:))
      .reduce(temp.get(), cfg.systemWrite(file:execute:))
      .map(execute)
    _ = try temp
      .map(requisition.decode(file:))
      .map(execute)
      .reduce(Plist.Provision.self, plistDecoder.decode(_:from:))
      .map(\.uuid)
      .map { "~/Library/MobileDevice/Provisioning Profiles/\($0).mobileprovision" }
      .map(ResolveAbsolutePath.make(path:))
      .map(resolveAbsolutePath)
      .reduce(temp.get(), cfg.systemMove(file:location:))
      .map(execute)
  }
}
