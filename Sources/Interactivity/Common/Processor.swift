import Foundation
import Facility
import FacilityPure
public struct Processor {
  private let process: Process = .init()
  private let pipe: Pipe = .init()
  private let task: Execute.Task
  private init(task: Execute.Task) {
    self.task = task
    process.launchPath = task.launch
    process.arguments = task.arguments
    process.environment = task.environment
    process.standardOutput = pipe
    if task.verbose {
      process.standardError = FileHandle.standardError
    } else {
      process.standardError = FileHandle.nullDevice
    }
  }
  private static func wire(pipe: Pipe, this: Self) -> Pipe {
    this.process.standardInput = pipe
    return this.pipe
  }
  private static func launch(this: Self) {
    this.process.launch()
  }
  private static func wait(this: Self) throws {
    this.process.waitUntilExit()
    if this.task.escalate && this.process.terminationStatus != 0 {
      throw Thrown("Process termination status \(this.process.terminationStatus)")
    }
  }
  public static func execute(query: Execute) throws -> Execute.Reply {
    let processors = query.tasks.map(Self.init(task:))
    let input = Pipe()
    let output = processors.reduce(input, Self.wire(pipe:this:))
    processors.forEach(Self.launch(this:))
    try query.input.map(input.fileHandleForWriting.write(contentsOf:))
    try input.fileHandleForWriting.close()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    try processors.forEach(Self.wait(this:))
    return data
  }
}
