import Foundation
import Testing
@testable import KOTCore

@Suite struct SettingsStoreTests {
    @Test func roundTrip() {
        let store = SettingsStore(store: InMemoryKeyValueStore())
        var settings = AppSettings()
        settings.slackMessage = SlackMessageSettings(
            enabled: true,
            channels: ["#ch1", "#ch2"],
            apiType: .incomingWebhook,
            webhookURLs: ["https://hooks.slack.com/services/a", "https://hooks.slack.com/services/b"],
            clockInMessage: "おはようございます",
            clockOutMessage: "お先に失礼します",
            breakStartMessage: "休憩入ります",
            breakEndMessage: "戻りました"
        )
        settings.slackStatus = SlackStatusSettings(
            enabled: true,
            clockIn: .init(emoji: ":office:", text: "仕事中"),
            clockOut: .init(emoji: ":house:", text: "退勤"),
            breakStart: .init(emoji: ":coffee:", text: "休憩中")
        )
        settings.googleChatWebhook = GoogleChatWebhookSettings(
            enabled: true,
            webhookURLs: ["https://chat.googleapis.com/v1/spaces/X/messages?key=k"],
            clockInMessage: "出社"
        )
        settings.googleChatUser = GoogleChatUserSettings(
            enabled: true,
            oauthClientID: "cid.apps.googleusercontent.com",
            spaces: ["AAA", "BBB"],
            clockInMessage: "出社しました。"
        )
        settings.recorder = RecorderSettings(domain: .s3, authMode: .saml)
        settings.debugLogging = true

        store.save(settings)
        #expect(store.load() == settings)
    }

    @Test func defaultsWhenEmpty() {
        let store = SettingsStore(store: InMemoryKeyValueStore())
        let settings = store.load()
        #expect(settings == AppSettings())
        #expect(settings.recorder.domain == .s2)
        #expect(settings.recorder.authMode == .account)
        #expect(settings.slackMessage.apiType == .asUser)
    }

    @Test func legacySpaceDelimitedStringsBecomeLists() {
        // Chrome 拡張はスペース区切りの文字列で保存していた
        let kv = InMemoryKeyValueStore()
        kv.set("#ch1 #ch2 #ch3", forKey: "slackChannel")
        kv.set("AAA BBB", forKey: "googleChatUserSpace")
        let settings = SettingsStore(store: kv).load()
        #expect(settings.slackMessage.channels == ["#ch1", "#ch2", "#ch3"])
        #expect(settings.googleChatUser.spaces == ["AAA", "BBB"])
    }

    @Test func recorderURLFollowsDomainAndAuthMode() {
        #expect(
            RecorderSettings(domain: .s2, authMode: .account).url.absoluteString
                == "https://s2.ta.kingoftime.jp/independent/recorder/personal/"
        )
        #expect(
            RecorderSettings(domain: .s4, authMode: .saml).url.absoluteString
                == "https://s4.ta.kingoftime.jp/independent/recorder2/personal/"
        )
    }
}
