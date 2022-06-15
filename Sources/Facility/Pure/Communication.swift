import Foundation
import Facility
public enum Communication {
  case slackHookTextMessage(SlackHookTextMessage)
  public struct SlackHookTextMessage {
    public var url: String
    public var messageTemplate: String
    public var userName: String?
    public var channel: String?
    public var emojiIcon: String?
    public init(
      url: String,
      yaml: Yaml.Controls.Communication.SlackHookTextMessage
    ) {
      self.url = url
      self.messageTemplate = yaml.messageTemplate
      self.userName = yaml.userName
      self.channel = yaml.channel
      self.emojiIcon = yaml.emojiIcon
    }
    public func makePayload(text: String) -> Payload { .init(
      text: text,
      username: userName,
      channel: channel.map { "#\($0)" },
      iconEmoji: emojiIcon.map { ":\($0):" }
    )}
    public struct Payload: Encodable {
      var text: String
      var username: String?
      var channel: String?
      var iconEmoji: String?
    }
  }
}
