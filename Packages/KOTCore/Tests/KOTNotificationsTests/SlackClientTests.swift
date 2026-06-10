import Foundation
import Testing
import KOTCore
@testable import KOTNotifications

@Suite struct SlackMessageClientTests {
    @Test func singleTokenIsSharedAcrossChannels() async {
        let transport = MockTransport()
        let client = SlackMessageClient(transport: transport)
        let results = await client.postAsUser(text: "出勤", channels: ["#a", "#b"], tokens: ["tok1"])

        #expect(results.map(\.success) == Array(repeating: true, count: results.count))
        let requests = transport.requests
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.url == SlackMessageClient.postMessageEndpoint })
        #expect(requests.allSatisfy { $0.bearerToken == "tok1" })
        #expect(requests[0].jsonBody["channel"] as? String == "#a")
        #expect(requests[1].jsonBody["channel"] as? String == "#b")
        #expect(requests[0].jsonBody["text"] as? String == "出勤")
        #expect(requests[0].jsonBody["as_user"] as? Bool == true)
    }

    @Test func multipleTokensRotateWithChannels() async {
        // トークンが複数のときだけチャンネルと同順で対応（原拡張の規則）
        let transport = MockTransport()
        let client = SlackMessageClient(transport: transport)
        _ = await client.postAsUser(text: "x", channels: ["#a", "#b"], tokens: ["tok1", "tok2"])

        #expect(transport.requests[0].bearerToken == "tok1")
        #expect(transport.requests[1].bearerToken == "tok2")
    }

    @Test func webhookPairsURLWithChannel() async {
        let transport = MockTransport()
        let client = SlackMessageClient(transport: transport)
        let results = await client.postViaWebhooks(
            text: "退勤",
            channels: ["#a", "#b"],
            webhookURLs: ["https://hooks.slack.com/services/1", "https://hooks.slack.com/services/2"]
        )

        #expect(results.map(\.success) == Array(repeating: true, count: results.count))
        let requests = transport.requests
        #expect(requests[0].url.absoluteString == "https://hooks.slack.com/services/1")
        #expect(requests[1].url.absoluteString == "https://hooks.slack.com/services/2")
        #expect(requests[0].jsonBody["channel"] as? String == "#a")
        #expect(requests[0].headers["Authorization"] == nil)
    }

    @Test func webhookMissingURLFailsThatChannelOnly() async {
        let transport = MockTransport()
        let client = SlackMessageClient(transport: transport)
        let results = await client.postViaWebhooks(
            text: "x",
            channels: ["#a", "#b"],
            webhookURLs: ["https://hooks.slack.com/services/1"]
        )
        #expect(results[0].success)
        #expect(!results[1].success)
        #expect(transport.requests.count == 1)
    }

    @Test func slackOKFalseIsFailure() async {
        // Slack API は HTTP 200 でも ok:false を返すことがある
        let transport = MockTransport { _ in
            HTTPResponse(statusCode: 200, body: Data(#"{"ok": false, "error": "channel_not_found"}"#.utf8))
        }
        let client = SlackMessageClient(transport: transport)
        let results = await client.postAsUser(text: "x", channels: ["#a"], tokens: ["tok"])
        #expect(!results[0].success)
        #expect(results[0].detail?.contains("channel_not_found") == true)
    }
}

@Suite struct SlackStatusClientTests {
    @Test func setsStatusPerToken() async {
        let transport = MockTransport()
        let client = SlackStatusClient(transport: transport)
        let status = SlackStatusSettings.Status(emoji: ":office:", text: "仕事中")
        let results = await client.setStatus(status, tokens: ["tok1", "tok2"])

        #expect(results.map(\.success) == Array(repeating: true, count: results.count))
        let requests = transport.requests
        #expect(requests.count == 2)
        #expect(requests.allSatisfy { $0.url == SlackStatusClient.endpoint })
        #expect(requests[0].bearerToken == "tok1")
        #expect(requests[1].bearerToken == "tok2")
        let profile = requests[0].jsonBody["profile"] as? [String: Any]
        #expect(profile?["status_emoji"] as? String == ":office:")
        #expect(profile?["status_text"] as? String == "仕事中")
        #expect(profile?["status_expiration"] as? Int == 0)
    }

    @Test func breakEndRevertsToClockInStatus() {
        let settings = SlackStatusSettings(
            enabled: true,
            clockIn: .init(emoji: ":office:", text: "仕事中"),
            clockOut: .init(emoji: ":house:", text: "退勤"),
            breakStart: .init(emoji: ":coffee:", text: "休憩中")
        )
        #expect(settings.status(for: .breakEnd) == settings.clockIn)
        #expect(settings.status(for: .breakStart).emoji == ":coffee:")
        #expect(settings.status(for: .clockOut).emoji == ":house:")
    }
}

@Suite struct GoogleChatWebhookClientTests {
    @Test func postsToAllURLs() async {
        let transport = MockTransport()
        let client = GoogleChatWebhookClient(transport: transport)
        let results = await client.post(text: "出社", webhookURLs: [
            "https://chat.googleapis.com/v1/spaces/A/messages?key=k1",
            "https://chat.googleapis.com/v1/spaces/B/messages?key=k2",
        ])

        #expect(results.map(\.success) == Array(repeating: true, count: results.count))
        #expect(transport.requests.count == 2)
        #expect(transport.requests[0].jsonBody["text"] as? String == "出社")
        #expect(transport.requests[0].headers["Authorization"] == nil)
    }
}
