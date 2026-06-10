import Foundation
import Testing
@testable import KOTCore

private func fixture(_ name: String) throws -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")!
    return try Data(contentsOf: url)
}

@Suite struct RecorderSnapshotTests {
    @Test func decodeSetting() throws {
        let setting = try RecorderSetting(json: fixture("SETTING"))
        #expect(setting.user.userToken == "abc123token")
        #expect(setting.timerecorder.recordButton.count == 4)
    }

    @Test func buttonResolutionByMark() throws {
        let setting = try RecorderSetting(json: fixture("SETTING"))
        #expect(setting.buttonID(for: .clockIn) == "100")
        #expect(setting.buttonID(for: .clockOut) == "200")
        #expect(setting.buttonID(for: .breakStart) == "300")
        #expect(setting.buttonID(for: .breakEnd) == "400")
    }

    @Test func breakButtonsMissing() throws {
        let setting = RecorderSetting.test(buttons: [
            .init(id: "1", mark: "1"),
            .init(id: "2", mark: "2"),
        ])
        #expect(setting.buttonID(for: .breakStart) == nil)
        #expect(setting.buttonID(for: .breakEnd) == nil)
    }

    @Test func decodeHistory() throws {
        let history = try RecordHistory.decode(json: fixture("RECORD_HISTORY"))
        #expect(history.count == 4)
        #expect(history[0].name == "休始")
        #expect(history[0].action == .breakStart)
        #expect(history[0].sendTimestamp == "20260610120000")
    }
}

extension RecorderSetting {
    static func test(buttons: [RecordButton]) -> RecorderSetting {
        let buttonsJSON = buttons
            .map { #"{"id": "\#($0.id)", "mark": "\#($0.mark)"}"# }
            .joined(separator: ",")
        let json = #"{"user": {"user_token": "t"}, "timerecorder": {"record_button": [\#(buttonsJSON)]}}"#
        return try! RecorderSetting(json: Data(json.utf8))
    }
}
