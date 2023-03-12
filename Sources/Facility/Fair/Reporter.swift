//import Foundation
//import Facility
//import FacilityPure
//public final class Reporter {
//  let execute: Try.Reply<Execute>
//  let generate: Try.Reply<Generate>
//  let resolveSecret: Try.Reply<Configuration.ResolveSecret>
//  let parseSlack: Try.Reply<ParseYamlFile<Chat.Slack>>
//  let parseRocket: Try.Reply<ParseYamlFile<Chat.Rocket>>
//  let parseChatStorage: Try.Reply<ParseYamlFile<Chat.Storage>>
//  let persistAsset: Try.Reply<Configuration.PersistAsset>
//  let logMessage: Act.Reply<LogMessage>
//  let jsonDecoder: JSONDecoder
//  public init(
//    execute: @escaping Try.Reply<Execute>,
//    generate: @escaping Try.Reply<Generate>,
//    resolveSecret: @escaping Try.Reply<Configuration.ResolveSecret>,
//    parseSlack: @escaping Try.Reply<ParseYamlFile<Chat.Slack>>,
//    parseRocket: @escaping Try.Reply<ParseYamlFile<Chat.Rocket>>,
//    parseChatStorage: @escaping Try.Reply<ParseYamlFile<Chat.Storage>>,
//    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>,
//    logMessage: @escaping Act.Reply<LogMessage>,
//    jsonDecoder: JSONDecoder
//  ) {
//    self.execute = execute
//    self.generate = generate
//    self.resolveSecret = resolveSecret
//    self.parseSlack = parseSlack
//    self.parseRocket = parseRocket
//    self.parseChatStorage = parseChatStorage
//    self.persistAsset = persistAsset
//    self.logMessage = logMessage
//    self.jsonDecoder = jsonDecoder
//  }
//  public func updateUser(
//    query: Gitlab.Storage.User.Update
//  ) throws -> Gitlab.Storage.User.Update.Reply {
//    try perform(cfg: query.cfg, action: { storage, gitlab in
//      try storage.bots.formUnion([gitlab.rest.get().user.username])
//      guard storage.bots.contains(query.user.login).not
//      else { throw Thrown("Updating a bot \(query.user.login)") }
//      storage.users[query.user.login] = query.user
//      return query.cfg.createGitlabStorageCommitMessage(
//        user: query.user.login,
//        reviews: [],
//        gitlab: gitlab,
//        reason: query.reason
//      )
//    })
//  }
//  public func registerChat(query: Chat.Register) throws -> Chat.Register.Reply {
//    let chat: Chat?
//    switch query.kind {
//    case .slack: chat = try makeSlack(cfg: query.cfg)
//    case .rocket: chat = try makeRocket(cfg: query.cfg)
//    }
//    guard let chat = chat else { throw Thrown("Not configured \(query.kind.rawValue)") }
//    try perform(cfg: query.cfg, chat: chat, action: { storage in
//      storage.users[query.gitlab] = query.user
//      return query.cfg.createChatStorageCommitMessage(
//        chat: chat, user: query.user, reason: .registerUser
//      )
//    })
//  }
//  public func clean(query: Chat.Clean) -> Chat.Clean.Reply {
//    do { try perform(cfg: query.cfg, action: { storage, gitlab in
//      var updated: [String] = []
//      for review in storage.reviews.keys {
//        guard query.reviews.contains(review).not else { continue }
//        storage.reviews[review] = nil
//        updated.append(review)
//      }
//      guard updated.isEmpty.not else { return nil }
//      return query.cfg.createGitlabStorageCommitMessage(
//        user: nil,
//        reviews: updated,
//        gitlab: gitlab,
//        reason: .cleanReviews
//      )
//    })} catch {
//      logMessage(.make(error: error))
//    }
//    do { try clean(clean: query, chat: makeSlack(cfg: query.cfg)) }
//    catch { logMessage(.make(error: error)) }
//    do { try clean(clean: query, chat: makeRocket(cfg: query.cfg)) }
//    catch { logMessage(.make(error: error)) }
//  }
//  public func sendReports(cfg: Configuration) {
//    var reports = Report.Bag.shared.reports
//    guard
//      reports.isEmpty.not,
//      let gitlab = try? cfg.gitlab.get(),
//      let project = try? gitlab.rest.map(\.project).get()
//    else { return }
//    let active = gitlab.storage.users
//      .filter(\.value.active)
//      .keySet
//      .subtracting(gitlab.storage.bots)
//    let info = gitlab.info
//    let jira = try? cfg.jira.get().info
//    for index in reports.indices {
//      reports[index].threads.users.formIntersection(active)
//      reports[index].threads.branches.remove(project.defaultBranch)
//      reports[index].info.env = cfg.env
//      reports[index].info.gitlab = info
//      reports[index].info.jira = jira
//    }
//    do { try sendGitlab(cfg: cfg, reports: reports) }
//    catch { logMessage(.make(error: error)) }
//    do { try send(cfg: cfg, chat: makeSlack(cfg: cfg), reports: reports) }
//    catch { logMessage(.make(error: error)) }
//    do { try send(cfg: cfg, chat: makeRocket(cfg: cfg), reports: reports) }
//    catch { logMessage(.make(error: error)) }
//    sendJira(cfg: cfg, reports: reports)
//  }
//}
//extension Reporter {
//  func makeSlack(cfg: Configuration) throws -> Chat? {
//    guard let slack = try cfg.parseSlack?.map(parseSlack).get() else { return nil }
//    let chat = try slack.makeChat(
//      url: resolveSecret(.init(cfg: cfg, secret: slack.url)),
//      token: resolveSecret(.init(cfg: cfg, secret: slack.token)),
//      slack: slack
//    )
//    return .slack(chat)
//  }
//  func makeRocket(cfg: Configuration) throws -> Chat? {
//    guard let rocket = try cfg.parseRocket?.map(parseRocket).get() else { return nil }
//    let chat = try rocket.makeChat(
//      url: resolveSecret(.init(cfg: cfg, secret: rocket.url)),
//      user: resolveSecret(.init(cfg: cfg, secret: rocket.user)),
//      token: resolveSecret(.init(cfg: cfg, secret: rocket.token)),
//      rocket: rocket
//    )
//    return .rocket(chat)
//  }
//  func sendJira(cfg: Configuration, reports: [Report]) {
//    guard let jira = try? cfg.jira.get() else { return }
//    for report in reports {
//      for issue in report.threads.issues {
//        for chain in jira.chains.filter(report.info.match(chain:)) {
//          var info = report.info
//          info.mark = chain.mark
//          info.jira?.issue = issue
//          do {
//            for link in chain.links {
//              guard let url = try generate(cfg.report(template: link.url, info: info)).notEmpty
//              else { continue }
//              let body: String?
//              if let template = link.body {
//                guard let data = try generate(cfg.report(template: template, info: info)).notEmpty
//                else { continue }
//                body = data
//              } else { body = nil }
//              let data = try Execute
//                .parseData(reply: execute(cfg.curl(
//                  jira: jira, url: url, method: link.method, body: body
//                )))
//                .notEmpty
//                .reduce(AnyCodable.self, jsonDecoder.decode(_:from:))
//              info.jira?.chain.append(data)
//            }
//          } catch {
//            logMessage(.make(error: error))
//          }
//        }
//      }
//    }
//  }
//  func sendGitlab(cfg: Configuration, reports: [Report]) throws {
//    try perform(cfg: cfg, action: { storage, gitlab in
//      var updated: [String] = []
//      if let template = gitlab.review {
//        for report in reports {
//          guard let update = report.info as? Generate.Info<Report.ReviewUpdated> else { continue }
//          do {
//            guard let text = try generate(cfg.report(template: template, info: update)).notEmpty
//            else { continue }
//            let review = "\(update.ctx.merge.iid)"
//            if let present = storage.reviews[review] { try gitlab
//              .putMrNotes(review: update.ctx.merge.iid, note: present, body: text)
//              .map(execute)
//              .map(Execute.checkStatus(reply:))
//              .get()
//            } else {
//              storage.reviews[review] = try gitlab
//                .postMrNotes(review: update.ctx.merge.iid, body: text)
//                .map(execute)
//                .reduce(Json.GitlabNote.self, jsonDecoder.decode(success:reply:))
//                .map(\.id)
//                .get()
//              updated.append(review)
//            }
//          } catch {
//            logMessage(.make(error: error))
//          }
//        }
//      }
//      for report in reports {
//        for review in report.threads.reviews {
//          for note in gitlab.notes.filter(report.info.match(note:)) {
//            var info = report.info
//            info.mark = note.mark
//            do {
//              guard let text = try generate(cfg.report(template: note.text, info: info)).notEmpty
//              else { continue }
//              _ = try gitlab
//                .postMrNotes(review: review.getUInt(), body: text)
//                .map(execute)
//                .reduce(Json.GitlabNote.self, jsonDecoder.decode(success:reply:))
//                .get()
//            } catch {
//              logMessage(.make(error: error))
//            }
//          }
//        }
//      }
//      guard updated.isEmpty.not else { return nil }
//      return cfg.createGitlabStorageCommitMessage(
//        user: nil,
//        reviews: updated,
//        gitlab: gitlab,
//        reason: .updateReviews
//      )
//    })
//  }
//  public func clean(clean: Chat.Clean, chat: Chat?) throws {
//    guard let chat = chat else { return }
//    try perform(cfg: clean.cfg, chat: chat, action: { storage in
//      storage.tags = storage.tags.filter({ clean.tags.contains($0.key) })
//      storage.issues = storage.issues.filter({ clean.issues.contains($0.key) })
//      storage.reviews = storage.reviews.filter({ clean.reviews.contains($0.key) })
//      storage.branches = storage.branches.filter({ clean.branches.contains($0.key) })
//      return clean.cfg.createChatStorageCommitMessage(
//        chat: chat,
//        user: nil,
//        reason: .cleanThreads
//      )
//    })
//  }
//  func send(cfg: Configuration, chat: Chat?, reports: [Report]) throws {
//    guard let chat = chat else { return }
//    try perform(cfg: cfg, chat: chat, action: { storage in
//      var updated = false
//      for var report in reports {
//        report.info.chat = storage.info
//        if send(storage: &storage, cfg: cfg, report: report) { updated = true }
//      }
//      guard updated else { return nil }
//      return cfg.createChatStorageCommitMessage(chat: chat, user: nil, reason: .createThreads)
//    })
//  }
//  func perform(
//    cfg: Configuration,
//    chat: Chat,
//    action: Act.In<Chat.Storage>.Do<Generate?>
//  ) throws {
//    var storage = try parseChatStorage(cfg.parseChatStorage(chat: chat))
//    guard let message = try action(&storage).map(generate) else { return }
//    _ = try persistAsset(.init(
//      cfg: cfg,
//      asset: chat.storage,
//      content: storage.serialized,
//      message: message
//    ))
//  }
//  func perform(
//    cfg: Configuration,
//    action: Try.In<Gitlab.Storage>.Of<Gitlab>.Do<Generate?>
//  ) throws {
//    let gitlab = try cfg.gitlab.get()
//    var storage = gitlab.storage
//    guard let message = try action(&storage, gitlab).map(generate) else { return }
//    _ = try persistAsset(.init(
//      cfg: cfg,
//      asset: storage.asset,
//      content: storage.serialized,
//      message: message
//    ))
//  }
//  func send(
//    storage: inout Chat.Storage,
//    cfg: Configuration,
//    report: Report
//  ) -> Bool {
//    for signal in storage.chat.diffusion.signals.filter(report.info.match(chat:)) {
//      var info = report.info
//      info.mark = signal.mark
//      _ = send(cfg: cfg, chat: storage.chat, thread: nil, signal: signal, info: info)
//    }
//    for user in report.threads.users {
//      guard let person = storage.users[user] else { continue }
//      for signal in storage.chat.diffusion.directs.filter(report.info.match(chat:)) {
//        var info = report.info
//        info.mark = signal.mark
//        info.chat?.person = person
//        _ = send(cfg: cfg, chat: storage.chat, thread: nil, signal: signal, info: info)
//      }
//    }
//    var updated = false
//    if send(
//      cfg: cfg,
//      chat: storage.chat,
//      keys: report.threads.tags,
//      info: report.info,
//      threads: storage.chat.diffusion.tags,
//      storage: &storage.tags
//    ) { updated = true }
//    if send(
//      cfg: cfg,
//      chat: storage.chat,
//      keys: report.threads.issues,
//      info: report.info,
//      threads: storage.chat.diffusion.issues,
//      storage: &storage.issues
//    ) { updated = true }
//    if send(
//      cfg: cfg,
//      chat: storage.chat,
//      keys: report.threads.reviews,
//      info: report.info,
//      threads: storage.chat.diffusion.reviews,
//      storage: &storage.reviews
//    ) { updated = true }
//    if send(
//      cfg: cfg,
//      chat: storage.chat,
//      keys: report.threads.branches,
//      info: report.info,
//      threads: storage.chat.diffusion.branches,
//      storage: &storage.branches
//    ) { updated = true }
//    return updated
//  }
//  func send(
//    cfg: Configuration,
//    chat: Chat,
//    keys: Set<String>,
//    info: GenerateInfo,
//    threads: [Chat.Diffusion.Thread],
//    storage: inout [String: [String: Chat.Storage.Thread]]
//  ) -> Bool {
//    var updated = false
//    guard keys.isEmpty.not else { return updated }
//    let create = Set(threads.filter(info.match(create:)).map(\.name))
//    let update = threads.reduce(into: [:], { $0[$1.name] = info.match(update: $1) })
//    for key in keys {
//      for thread in threads {
//        guard let present = storage[key]?[thread.name] else {
//          guard create.contains(thread.name) else { continue }
//          var info = info
//          info.mark = thread.name
//          if let thread = send(
//            cfg: cfg, chat: chat, thread: thread.name, signal: thread.create, info: info
//          ) {
//            updated = true
//            storage[key, default: [:]][thread.name] = thread
//          }
//          continue
//        }
//        for signal in update[thread.name].get([]) {
//          var info = info
//          info.mark = thread.name
//          info.chat?.thread = .make(signal: signal, thread: present)
//          _ = send(cfg: cfg, chat: chat, thread: nil, signal: signal, info: info)
//        }
//      }
//    }
//    return updated
//  }
//  func send(
//    cfg: Configuration,
//    chat: Chat,
//    thread: String?,
//    signal: Chat.Diffusion.Signal,
//    info: GenerateInfo
//  ) -> Chat.Storage.Thread? {
//    let body: String
//    do {
//      body = try generate(cfg.report(template: signal.body, info: info))
//    } catch {
//      log(info: info, signal: signal, error: error, action: "Generate", chat: chat)
//      return nil
//    }
//    guard body.isEmpty.not else { return nil }
//    defer { sleep(1) }
//    let data: Data
//    do {
//      data = try Execute.parseData(reply: execute(cfg.curl(chat: chat, signal: signal, body: body)))
//    } catch {
//      log(info: info, signal: signal, error: error, action: "Send", chat: chat)
//      return nil
//    }
//    guard let thread = thread else { return nil }
//    do {
//      switch chat {
//      case .slack: return try .make(
//        name: thread,
//        slack: jsonDecoder.decode(Json.SlackMessage.self, from: data)
//      )
//      case .rocket: return try .make(
//        name: thread,
//        rocket: jsonDecoder.decode(Json.RocketReply.self, from: data)
//      )}
//    } catch {
//      log(info: info, signal: signal, error: error, action: "Parse", chat: chat)
//      return nil
//    }
//  }
//  func log(
//    info: GenerateInfo,
//    signal: Chat.Diffusion.Signal,
//    error: Error,
//    action: String,
//    chat: Chat
//  ) {
//    let event = info.event.joined(separator: "/")
//    let mark = signal.mark
//    logMessage(.init(message: "\(action) \(chat.kind.rawValue) \(event) by \(mark) error: \(error)"))
//  }
//}
