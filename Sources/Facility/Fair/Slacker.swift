import Foundation
import Facility
import FacilityPure
public final class Slacker {
  let parseSlackStorage: Try.Reply<ParseYamlFile<Slack.Storage>>
  let persistAsset: Try.Reply<Configuration.PersistAsset>
  public init(
    parseSlackStorage: @escaping Try.Reply<ParseYamlFile<Slack.Storage>>,
    persistAsset: @escaping Try.Reply<Configuration.PersistAsset>
  ) {
    self.parseSlackStorage = parseSlackStorage
    self.persistAsset = persistAsset
  }
  public func registerSlackUser(query: Slack.RegisterUser) throws -> Slack.RegisterUser.Reply {
    perform(cfg: query.cfg, message: "Register \(query.gitlab)", action: {
      $0.users[query.gitlab] = query.slack
    })
  }
  func perform(cfg: Configuration, message: String, action: Act.In<Slack.Storage>.Go) {
    guard
      let slack = try? cfg.slack.get(),
      var storage = try? parseSlackStorage(cfg.parseSlackStorage(slack: slack))
    else { return }
    defer { _ = try? persistAsset(.init(
      cfg: cfg,
      asset: slack.storage,
      content: storage.serialized,
      message: message
    ))}
    action(&storage)
  }
}
