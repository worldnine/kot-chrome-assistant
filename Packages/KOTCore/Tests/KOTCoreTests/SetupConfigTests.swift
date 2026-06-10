import Foundation
import Testing
@testable import KOTCore

@Suite struct SetupConfigTests {
    private func base64(_ json: String) -> String {
        Data(json.utf8).base64EncodedString()
    }

    @Test func parseFromLegacyOptionsURL() throws {
        let payload = base64(#"{"clientId": "cid", "space": "AAA BBB"}"#)
        let config = try SetupConfig.parse("chrome-extension://abc/options.html#setup=\(payload)")
        #expect(config.clientId == "cid")
        #expect(config.space == "AAA BBB")
    }

    @Test func parseFromCustomScheme() throws {
        let payload = base64(#"{"clientId": "cid2"}"#)
        let config = try SetupConfig.parse("kotassistant://setup?d=\(payload)")
        #expect(config.clientId == "cid2")
    }

    @Test func parseFromBareBase64() throws {
        let payload = base64(#"{"clockIn": "おはよう"}"#)
        let config = try SetupConfig.parse(payload)
        #expect(config.clockIn == "おはよう")
    }

    @Test func parseRejectsGarbage() {
        #expect(throws: SetupConfig.ParseError.self) {
            try SetupConfig.parse("!!! not base64 !!!")
        }
    }

    @Test func mergePrecedenceURLOverExisting() throws {
        var settings = GoogleChatUserSettings(
            enabled: false,
            oauthClientID: "old-cid",
            spaces: ["AAA"],
            clockInMessage: "既存出社"
        )
        let config = SetupConfig(clientId: "new-cid", space: "BBB AAA", clockIn: "URL出社")
        config.apply(to: &settings)

        #expect(settings.enabled)
        #expect(settings.oauthClientID == "new-cid")
        // スペースは追加式（既存保持・重複排除）
        #expect(settings.spaces == ["AAA", "BBB"])
        #expect(settings.clockInMessage == "URL出社")
    }

    @Test func mergeKeepsExistingWhenURLOmits() {
        var settings = GoogleChatUserSettings(oauthClientID: "old-cid", clockInMessage: "既存出社")
        SetupConfig(space: "CCC").apply(to: &settings)
        #expect(settings.oauthClientID == "old-cid")
        #expect(settings.clockInMessage == "既存出社")
        #expect(settings.spaces == ["CCC"])
    }

    @Test func mergeFallsBackToDefaults() {
        var settings = GoogleChatUserSettings()
        SetupConfig(clientId: "cid").apply(to: &settings)
        #expect(settings.clockInMessage == SetupConfig.Defaults.clockIn)
        #expect(settings.clockOutMessage == SetupConfig.Defaults.clockOut)
        #expect(settings.breakStartMessage == SetupConfig.Defaults.breakStart)
        #expect(settings.breakEndMessage == SetupConfig.Defaults.breakEnd)
    }
}
