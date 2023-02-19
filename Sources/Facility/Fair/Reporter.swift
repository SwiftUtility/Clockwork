import Foundation
import Facility
import FacilityPure
public final class Reporter {
  let execute: Try.Reply<Execute>
  let sendSlack: Act.Reply<Slack.Send>
  let logMessage: Act.Reply<LogMessage>
  let jsonDecoder: JSONDecoder
  public init(
    execute: @escaping Try.Reply<Execute>,
    sendSlack: @escaping Act.Reply<Slack.Send>,
    logMessage: @escaping Act.Reply<LogMessage>,
    jsonDecoder: JSONDecoder
  ) {
    self.execute = execute
    self.sendSlack = sendSlack
    self.logMessage = logMessage
    self.jsonDecoder = jsonDecoder
  }
  public func sendReports(cfg: Configuration) {
    var reports = Report.Bag.shared.reports
    guard
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
  }
}
