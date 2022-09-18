import Foundation
import Facility
import FacilityPure
public struct Processor {
  private let process: Process = .init()
  private let pipe: Pipe = .init()
  private let log: Pipe = .init()
  private let task: Execute.Task
  private init(task: Execute.Task) {
    self.task = task
    process.launchPath = task.launch
    process.arguments = task.arguments
    process.environment = ["LC_ALL": "en_US.UTF-8", "LANG": "en_US.UTF-8"]
    for (key, value) in task.environment {
      process.environment?[key] = value
    }
    process.standardOutput = pipe
    process.standardError = log
  }
  private static func wire(pipe: Pipe, this: Self) -> Pipe {
    this.process.standardInput = pipe
    return this.pipe
  }
  private static func launch(this: Self) {
    this.process.launch()
  }
  private static func wait(this: Self) throws -> Execute.Reply.Status {
    let stderr = try? this.log.fileHandleForReading.readToEnd()
    this.process.waitUntilExit()
    return .init(
      task: this.task,
      stderr: stderr,
      termination: this.process.terminationStatus
    )
  }
  public static func execute(query: Execute) throws -> Execute.Reply {
    let processors = query.tasks.map(Self.init(task:))
    let input = Pipe()
    let output = processors.reduce(input, Self.wire(pipe:this:))
    processors.forEach(Self.launch(this:))
    try query.input.map(input.fileHandleForWriting.write(contentsOf:))
    try input.fileHandleForWriting.close()
    let data = try output.fileHandleForReading.readToEnd()
    let statuses = try processors.map(Self.wait(this:))
    return .init(data: data, statuses: statuses)
  }
}
