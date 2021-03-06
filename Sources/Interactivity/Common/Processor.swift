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
    if task.verbose { process.standardError = Pipe() }
  }
  private static func wire(pipe: Pipe, this: Self) -> Pipe {
    this.process.standardInput = pipe
    return this.pipe
  }
  private static func launch(this: Self) {
    this.process.launch()
  }
  private static func wait(this: Self) throws -> Execute.Reply.Status {
    let stderr = try this.process.standardError
      .flatMap { $0 as? Pipe }
      .map(\.fileHandleForReading)
      .flatMap { try $0.readToEnd() }
    this.process.waitUntilExit()
    if this.process.terminationStatus != 0 && this.task.escalate {
      try FileHandle.standardError.write(contentsOf: Data((
        ["\(this.process.terminationStatus): \(this.task.launch)"]
        + this.task.arguments.map { "  \($0)" }
      ).map { "\($0)\n" }.joined().utf8))
      try stderr.map(FileHandle.standardError.write(contentsOf:))
    }
    return .init(termination: this.process.terminationStatus, task: this.task)
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
