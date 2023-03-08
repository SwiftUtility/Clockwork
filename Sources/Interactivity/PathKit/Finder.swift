import Foundation
import PathKit
import Interactivity
import Facility
import FacilityPure
import InteractivityCommon
public final class Finder {
  public static func listDirectories(path: Ctx.Sys.Absolute) throws -> [String] {
    let path = Path(path.value)
    try ensure(isDirectory: path)
    return try path.children().filter(\.isDirectory).map(\.lastComponent)
  }
  public static func resolveAbsolute(query: Files.ResolveAbsolute) throws -> Files.ResolveAbsolute.Reply {
    var path = Path(query.path)
    guard path.isRelative else { return try .init(value: path.normalize().string) }
    try? path = Path(?!query.relativeTo?.value) + path
    return try .init(value: path.absolute().string)
  }
  public static func resolveFileDirectory(path: String) throws -> String {
    return Path(path).parent().absolute().string
  }
  public static func resolveFile(path: String) throws -> String {
    return Path(path).absolute().string
  }
  public static func writeFile(query: Files.WriteFile) throws -> Files.WriteFile.Reply {
    try Path(query.file.value).write(query.data)
  }
  public static func readFile(query: Files.ReadFile) throws -> Files.ReadFile.Reply {
    try .init(contentsOf: .init(fileURLWithPath: query.file.value))
  }
  static func ensure(isDirectory path: PathKit.Path) throws {
    try path.isDirectory.else { throw Thrown("Not a directory \(path.absolute().string)") }
  }
  public static func resolve(
    query: Ctx.Sys.Absolute.Resolve
  ) throws -> Ctx.Sys.Absolute.Resolve.Reply {
    let path = query.relativeTo.map({ "\($0.value)/\(query.path)" }).get(query.path)
    return try .make(value: Path(path).absolute().string)
  }
  public static func parent(
    path: Ctx.Sys.Absolute
  ) throws -> Ctx.Sys.Absolute {
    return try .make(value: Path(path.value).parent().absolute().string)
  }
}
