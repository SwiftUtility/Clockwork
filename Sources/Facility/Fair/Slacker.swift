import Foundation
import Facility
import FacilityPure
public final class Slacker {
  let execute: Try.Reply<Execute>
  let generate: Try.Reply<Generate>
  let logMessage: Act.Reply<LogMessage>
  let parseSlackStorage: Try.Reply<ParseYamlFile<Slack.Storage>>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    generate: @escaping Try.Reply<Generate>,
    logMessage: @escaping Act.Reply<LogMessage>,
    parseSlackStorage: @escaping Try.Reply<ParseYamlFile<Slack.Storage>>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.generate = generate
    self.logMessage = logMessage
    self.parseSlackStorage = parseSlackStorage
    self.persistAsset = persistAsset
    self.jsonDecoder = jsonDecoder
  }
  public func registerSlackUser(query: Slack.RegisterUser) throws -> Slack.RegisterUser.Reply {
    perform(cfg: query.cfg, message: "Register \(query.gitlab)", action: { storage in
      storage.users[query.gitlab] = query.slack
      return query.cfg.createSlackStorageCommitMessage(
        slack: storage.slack,
        user: query.gitlab,
        reason: .registerUser
      )
    })
  }
  public func sendSlack(query: Slack.Send) -> Slack.Send.Reply {
    perform(cfg: query.cfg, message: "Update threads", action: { storage in
      for var report in query.reports {
        report.info.slack = storage.slack.info
        send(storage: &storage, cfg: query.cfg, report: report)
      }
      return query.cfg.createSlackStorageCommitMessage(
        slack: storage.slack,
        user: nil,
        reason: .registerUser
      )
    })
  }
  func send(
    storage: inout Slack.Storage,
    cfg: Configuration,
    report: Report
  ) {
    for signal in storage.slack.signals.filter(report.info.match(signal:)) {
      var info = report.info
      info.mark = signal.mark
      _ = send(cfg: cfg, slack: storage.slack, signal: signal, info: info)
    }
    for user in report.threads.users {
      guard let person = storage.users[user] else { continue }
      for signal in storage.slack.directs.filter(report.info.match(signal:)) {
        var info = report.info
        info.mark = signal.mark
        info.slack?.person = person
        _ = send(cfg: cfg, slack: storage.slack, signal: signal, info: info)
      }
    }
    send(
      cfg: cfg,
      slack: storage.slack,
      keys: report.threads.tags,
      info: report.info,
      threads: storage.slack.tags,
      storage: &storage.tags
    )
    send(
      cfg: cfg,
      slack: storage.slack,
      keys: report.threads.issues,
      info: report.info,
      threads: storage.slack.issues,
      storage: &storage.issues
    )
    send(
      cfg: cfg,
      slack: storage.slack,
      keys: report.threads.reviews,
      info: report.info,
      threads: storage.slack.reviews,
      storage: &storage.reviews
    )
    send(
      cfg: cfg,
      slack: storage.slack,
      keys: report.threads.branches,
      info: report.info,
      threads: storage.slack.branches,
      storage: &storage.branches
    )
  }
  func perform(
    cfg: Configuration,
    message: String,
    action: Act.In<Slack.Storage>.Do<Generate?>
  ) {
    guard
      let slack = try? cfg.slack.get(),
      var storage = try? parseSlackStorage(cfg.parseSlackStorage(slack: slack))
    else { return }
    guard let message = try? action(&storage).map(generate) else { return }
    _ = try? persistAsset(.init(
      cfg: cfg,
      asset: slack.storage,
      content: storage.serialized,
      message: message
    ))
  }
  func send(
    cfg: Configuration,
    slack: Slack,
    keys: Set<String>,
    info: GenerateInfo,
    threads: [Slack.Thread],
    storage: inout [String: [String: Slack.Storage.Thread]]
  ) {
    guard keys.isEmpty.not else { return }
    let create = Set(threads.filter(info.match(create:)).map(\.name))
    let update = threads.reduce(into: [:], { $0[$1.name] = info.match(update: $1) })
    for key in keys {
      for thread in threads {
        guard let present = storage[key]?[thread.name] else {
          guard create.contains(thread.name) else { continue }
          var info = info
          info.mark = thread.name
          if let json = send(cfg: cfg, slack: slack, signal: thread.create, info: info) {
            storage[key, default: [:]][thread.name] = .make(name: thread.name, json: json)
          }
          continue
        }
        guard let signals = update[thread.name] else { continue }
        var info = info
        info.mark = thread.name
        for signal in signals {
          info.slack?.thread = .make(signal: signal, thread: present)
          _ = send(cfg: cfg, slack: slack, signal: signal, info: info)
        }
      }
    }
  }
  func send(
    cfg: Configuration,
    slack: Slack,
    signal: Slack.Signal,
    info: GenerateInfo
  ) -> Json.SlackMessage? {
    let body: String
    do {
      body = try generate(cfg.report(template: signal.body, info: info))
    } catch {
      log(info: info, signal: signal, error: error, action: "generate")
      return nil
    }
    guard body.isEmpty.not else { return nil }
    defer { sleep(1) }
    do {
      let data = try Execute.parseData(reply: execute(cfg.curlSlack(
        token: slack.token, method: signal.method, body: body
      )))
      return try? jsonDecoder.decode(Json.SlackMessage.self, from: data)
    } catch {
      log(info: info, signal: signal, error: error, action: "send")
      return nil
    }
  }
  func log(info: GenerateInfo, signal: Slack.Signal, error: Error, action: String) {
    let event = info.event.joined(separator: "/")
    let mark = signal.mark
    logMessage(.init(message: "Slack \(action) \(event) by \(mark) error: \(error)"))
  }
}
