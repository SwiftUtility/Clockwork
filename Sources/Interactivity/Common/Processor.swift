import Foundation
import Facility
import FacilityAutomates
import FacilityQueries
public struct Processor {
  private let task: Process = .init()
  private let pipe: Pipe = .init()
  private let pipeTask: PipeTask
  private init(pipeTask: PipeTask) {
    self.pipeTask = pipeTask
    task.launchPath = pipeTask.launchPath
    task.arguments = pipeTask.arguments
    task.environment = pipeTask.environment
    task.standardInput = FileHandle.nullDevice
    task.standardOutput = pipe
    if pipeTask.surpassStdErr {
      task.standardError = FileHandle.nullDevice
    } else {
      task.standardError = FileHandle.standardError
    }
  }
  private static func chain(pipe: Pipe, item: Self) -> Pipe {
    item.task.standardInput = pipe
    return item.pipe
  }
  private static func run(this: Self) throws {
    this.task.launch()
  }
  private static func wait(this: Self) throws {
    this.task.waitUntilExit()
    if this.pipeTask.escalateFailure && this.task.terminationStatus != 0 {
      throw Thrown("Exit with \(this.task.terminationStatus): \(this.pipeTask.bash)")
    }
  }
  public static func handleProcess<T: ProcessHandler>(query: T) throws -> T.Reply {
    let items = query.tasks.map(Self.init(pipeTask:))
    guard var pipe = items.first?.pipe else { throw MayDay("ExecuteProcess made no tasks") }
    pipe = items.dropFirst().reduce(pipe, Self.chain(pipe:item:))
    try items.forEach(Self.run(this:))
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    try items.forEach(Self.wait(this:))
    return try query.handle(data: data)
  }
}
