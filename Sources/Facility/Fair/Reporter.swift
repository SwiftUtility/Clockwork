import Foundation
import Facility
import FacilityPure
public final class Reporter {
  let execute: Try.Reply<Execute>
  let generate: Try.Reply<Generate>
  let sendSlack: Act.Reply<Slack.Send>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    generate: @escaping Try.Reply<Generate>,
    sendSlack: @escaping Act.Reply<Slack.Send>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.generate = generate
    self.sendSlack = sendSlack
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func sendReports(cfg: Configuration) {
    var reports = Report.Bag.shared.reports
    guard
      reports.isEmpty.not,
      let gitlab = try? cfg.gitlab.get(),
      let project = try? gitlab.rest.map(\.project).get()
    else { return }
    let active = gitlab.storage.users
      .filter(\.value.active)
      .keySet
      .subtracting(gitlab.storage.bots)
    let info = gitlab.info
    let jira = try? cfg.jira.get().info
    for index in reports.indices {
      reports[index].threads.users.formIntersection(active)
      reports[index].threads.branches.remove(project.defaultBranch)
      reports[index].info.env = cfg.env
      reports[index].info.gitlab = info
      reports[index].info.jira = jira
    }
    sendSlack(.make(cfg: cfg, reports: reports))
    sendJira(cfg: cfg, reports: reports)
  }
}
extension Reporter {
  func sendJira(cfg: Configuration, reports: [Report]) {
    guard let jira = try? cfg.jira.get() else { return }
    for report in reports {
      for issue in report.threads.issues {
        for chain in jira.chains.filter(report.info.match(chain:)) {
          var info = report.info
          info.mark = chain.mark
          info.jira?.issue = issue
          do {
            for link in chain.links {
              guard let url = try generate(cfg.report(template: link.url, info: info)).notEmpty
              else { continue }
              let body = try link.body
                .flatMap({ try generate(cfg.report(template: $0, info: info)).notEmpty })
              let data = try Execute
                .parseData(reply: execute(cfg.curlJira(
                  jira: jira, url: url, method: link.method, body: body
                )))
                .notEmpty
                .reduce(AnyCodable.self, jsonDecoder.decode(_:from:))
              info.jira?.chain.append(data)
            }
          } catch {
            logMessage(.make(error: error))
          }
        }
      }
    }
  }
}
