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
    try perform(cfg: query.cfg, action: { storage in
      storage.users[query.gitlab] = query.slack
      return query.cfg.createSlackStorageCommitMessage(
        slack: storage.slack,
        user: query.gitlab,
        reason: .registerUser
      )
    })
  }
  public func cleanSlack(query: Configuration.Clean) throws -> Configuration.Clean.Reply {
    try perform(cfg: query.cfg, action: { storage in
      storage.tags = storage.tags.filter({ query.tags.contains($0.key) })
      storage.issues = storage.issues.filter({ query.issues.contains($0.key) })
      storage.reviews = storage.reviews.filter({ query.reviews.contains($0.key) })
      storage.branches = storage.branches.filter({ query.branches.contains($0.key) })

      return query.cfg.createSlackStorageCommitMessage(
        slack: storage.slack,
        user: nil,
        reason: .cleanThreads
      )
    })
  }
  public func sendSlack(query: Slack.Send) -> Slack.Send.Reply {
    do {
      try perform(cfg: query.cfg, action: { storage in
        var updated = false
        for var report in query.reports {
          report.info.slack = storage.slack.info
          if send(storage: &storage, cfg: query.cfg, report: report) { updated = true }
        }
        guard updated else { return nil }
        return query.cfg.createSlackStorageCommitMessage(
          slack: storage.slack,
          user: nil,
          reason: .createThreads
        )
      })
    } catch {
      logMessage(.make(error: error))
    }
  }
  func send(
    storage: inout Slack.Storage,
    cfg: Configuration,
    report: Report
  ) -> Bool {
    for signal in storage.slack.signals.filter(report.info.match(slack:)) {
      signal.mark.debug()
      var info = report.info
      info.mark = signal.mark
      _ = send(cfg: cfg, slack: storage.slack, signal: signal, info: info)
    }
    for user in report.threads.users {
      user.debug()
      guard let person = storage.users[user] else { continue }
      for signal in storage.slack.directs.filter(report.info.match(slack:)) {
        var info = report.info
        info.mark = signal.mark
        info.slack?.person = person
        _ = send(cfg: cfg, slack: storage.slack, signal: signal, info: info)
      }
    }
    var updated = false
    if send(
      cfg: cfg,
      slack: storage.slack,
      keys: report.threads.tags,
      info: report.info,
      threads: storage.slack.tags,
      storage: &storage.tags
    ) { updated = true }
    if send(
      cfg: cfg,
      slack: storage.slack,
      keys: report.threads.issues,
      info: report.info,
      threads: storage.slack.issues,
      storage: &storage.issues
    ) { updated = true }
    if send(
      cfg: cfg,
      slack: storage.slack,
      keys: report.threads.reviews,
      info: report.info,
      threads: storage.slack.reviews,
      storage: &storage.reviews
    ) { updated = true }
    if send(
      cfg: cfg,
      slack: storage.slack,
      keys: report.threads.branches,
      info: report.info,
      threads: storage.slack.branches,
      storage: &storage.branches
    ) { updated = true }
    return updated
  }
  func perform(
    cfg: Configuration,
    action: Act.In<Slack.Storage>.Do<Generate?>
  ) throws {
    let slack = try cfg.slack.get()
    var storage = try parseSlackStorage(cfg.parseSlackStorage(slack: slack))
    guard let message = try action(&storage).map(generate) else { return }
    _ = try persistAsset(.init(
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
  ) -> Bool {
    var updated = false
    guard keys.isEmpty.not else { return updated }
    let create = Set(threads.filter(info.match(create:)).map(\.name))
    let update = threads.reduce(into: [:], { $0[$1.name] = info.match(update: $1) })
    for key in keys {
      for thread in threads {
        thread.name.debug()
        guard let present = storage[key]?[thread.name] else {
          guard create.contains(thread.name) else { continue }
          var info = info
          info.mark = thread.name
          if let json = send(cfg: cfg, slack: slack, signal: thread.create, info: info) {
            updated = true
            storage[key, default: [:]][thread.name] = .make(name: thread.name, json: json)
          }
          continue
        }
        guard let signals = update[thread.name] else { continue }
        for signal in signals {
          var info = info
          info.mark = thread.name
          info.slack?.thread = .make(signal: signal, thread: present)
          signal.events.debug()
          _ = send(cfg: cfg, slack: slack, signal: signal, info: info)
        }
      }
    }
    return updated
  }
  func send(
    cfg: Configuration,
    slack: Slack,
    signal: Slack.Signal,
    info: GenerateInfo
  ) -> Json.SlackMessage? {
    let body: String
    do {
      body = try generate(cfg.report(template: signal.body, info: info)).debug()
    } catch {
      log(info: info, signal: signal, error: error, action: "generate")
      return nil
    }
    guard body.isEmpty.not else { return nil }
    defer { sleep(1) }
    do {
      let data = try Execute.parseData(reply: execute(cfg.curlSlack(
        token: slack.token, method: signal.method.debug(), body: body
      )))
      String(data: data, encoding: .utf8)?.debug()
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
