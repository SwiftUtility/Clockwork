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
      for signal in jira.issues.filter(report.info.match(jira:)) {
        for issue in report.threads.issues {
          var info = report.info
          info.jira?.issue = issue
          do {
            let url = try generate(cfg.report(template: signal.url, info: info))
            let body = try generate(cfg.report(template: signal.body, info: info))
            try Execute.checkStatus(reply: execute(cfg.curlJira(
              jira: jira, url: url, method: signal.method, body: body
            )))
          } catch {
            logMessage(.make(error: error))
          }
        }
      }
    }
  }
}
