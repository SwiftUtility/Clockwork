import Foundation
import PathKit
import Interactivity
import Facility
import FacilityPure
import InteractivityCommon
public final class Finder {
  let root: PathKit.Path
  let fileManager: FileManager
  public init(root: String, fileManager: FileManager = .default) {
    self.root = Path(root).absolute()
    self.fileManager = fileManager
  }
  public func createFile(query: Files.CreateFile) throws -> Files.CreateFile.Reply {
    var path = Path(query.file.value)
    if path.isRelative { path = root + path }
    try path.parent().absolute().mkpath()
    path = path.absolute()
    try fileManager
      .createFile(atPath: path.string, contents: query.data)
      .else { throw Thrown("Write error \(path.string)") }
  }
  public func delete(path: String) throws {
    var path = Path(path)
    if path.isRelative { path = root + path }
    path = path.absolute()
    if path.exists { try path.delete() }
  }
  public func listFileSystem(query: Files.ListFileSystem) throws -> Files.ListFileSystem.Reply {
    var path = Path(query.path.value)
    if path.isRelative { path = root + path }
    try ensure(isDirectory: path)
    let children = try path.children().compactMap { child in
      (query.include.files && child.isFile).then(child.lastComponent) ??
      (query.include.directories && child.isDirectory).then(child.lastComponent)
    }
    return AnyIterator(children.makeIterator())
  }
  func ensure(isDirectory path: PathKit.Path) throws {
    try path.isDirectory.else { throw Thrown("Not a directory \(path.absolute().string)") }
  }
  public static func resolveAbsolute(query: Files.ResolveAbsolute) throws -> Files.ResolveAbsolute.Reply {
    var path = Path(query.path)
    guard path.isRelative else { return try .init(value: path.normalize().string) }
    try? path = Path(?!query.relativeTo?.value) + path
    return try .init(value: path.absolute().string)
  }
  public static func writeFile(query: Files.WriteFile) throws -> Files.WriteFile.Reply {
    try Path(query.file.value).write(query.data)
  }
  public static func readFile(query: Files.ReadFile) throws -> Files.ReadFile.Reply {
    try .init(contentsOf: .init(fileURLWithPath: query.file.value))
  }
}
