import Foundation
import Testing
import KOTCore
@testable import KOTNotifications

@Suite struct NotificationDispatcherTests {
    private func makeDispatcher(transport: MockTransport, secrets: InMemorySecretStore) -> NotificationDispatcher {
        let oauth = GoogleOAuthService(transport: transport, secrets: secrets)
        return NotificationDispatcher(transport: transport, oauth: oauth, secrets: secrets, log: { _, _ in })
    }

    @Test func disabledIntegrationsDoNotPost() async {
        let transport = MockTransport()
        let dispatcher = makeDispatcher(transport: transport, secrets: InMemorySecretStore())

        var settings = AppSettings()
        settings.slackMessage.enabled = false
        settings.slackMessage.channels = ["#a"]
        settings.slackMessage.clockInMessage = "出勤"

        await dispatcher.dispatch(.clockIn, settings: settings)
        #expect(transport.requests.isEmpty)
    }

    @Test func emptyMessageSkipsThatIntegration() async {
        // メッセージ未設定のアクションは送らない（原拡張と同じ）
        let transport = MockTransport()
        let secrets = InMemorySecretStore()
        try! secrets.setSecret("tok", for: .slackToken)
        let dispatcher = makeDispatcher(transport: transport, secrets: secrets)

        var settings = AppSettings()
        settings.slackMessage.enabled = true
        settings.slackMessage.channels = ["#a"]
        settings.slackMessage.clockInMessage = "出勤"
        settings.slackMessage.clockOutMessage = ""

        await dispatcher.dispatch(.clockOut, settings: settings)
        #expect(transport.requests.isEmpty)
    }

    @Test func enabledIntegrationsFanOut() async {
        let transport = MockTransport()
        let secrets = InMemorySecretStore()
        try! secrets.setSecret("msg-tok", for: .slackToken)
        try! secrets.setSecret("status-tok", for: .slackStatusToken)
        let dispatcher = makeDispatcher(transport: transport, secrets: secrets)

        var settings = AppSettings()
        settings.slackMessage.enabled = true
        settings.slackMessage.channels = ["#a"]
        settings.slackMessage.clockInMessage = "出勤しました"
        settings.slackStatus.enabled = true
        settings.slackStatus.clockIn = .init(emoji: ":office:", text: "仕事中")
        settings.googleChatWebhook.enabled = true
        settings.googleChatWebhook.webhookURLs = ["https://chat.googleapis.com/v1/spaces/X/messages?key=k"]
        settings.googleChatWebhook.clockInMessage = "出社"

        await dispatcher.dispatch(.clockIn, settings: settings)

        let urls = Set(transport.requests.map(\.url.absoluteString))
        #expect(urls.contains("https://slack.com/api/chat.postMessage"))
        #expect(urls.contains("https://slack.com/api/users.profile.set"))
        #expect(urls.contains("https://chat.googleapis.com/v1/spaces/X/messages?key=k"))
        #expect(transport.requests.count == 3)
    }

    @Test func breakEndSendsClockInStatus() async {
        let transport = MockTransport()
        let secrets = InMemorySecretStore()
        try! secrets.setSecret("status-tok", for: .slackStatusToken)
        let dispatcher = makeDispatcher(transport: transport, secrets: secrets)

        var settings = AppSettings()
        settings.slackStatus.enabled = true
        settings.slackStatus.clockIn = .init(emoji: ":office:", text: "仕事中")
        settings.slackStatus.breakStart = .init(emoji: ":coffee:", text: "休憩中")

        await dispatcher.dispatch(.breakEnd, settings: settings)

        let profile = transport.requests[0].jsonBody["profile"] as? [String: Any]
        #expect(profile?["status_emoji"] as? String == ":office:")
        #expect(profile?["status_text"] as? String == "仕事中")
    }

    @Test func googleChatUserRequiresCredentialsAndSpaces() async {
        // clientSecret が未設定なら投稿しない（原拡張と同じガード）
        let transport = MockTransport()
        let dispatcher = makeDispatcher(transport: transport, secrets: InMemorySecretStore())

        var settings = AppSettings()
        settings.googleChatUser.enabled = true
        settings.googleChatUser.oauthClientID = "cid"
        settings.googleChatUser.spaces = ["AAA"]
        settings.googleChatUser.clockInMessage = "出社"

        await dispatcher.dispatch(.clockIn, settings: settings)
        #expect(transport.requests.isEmpty)
    }
}
