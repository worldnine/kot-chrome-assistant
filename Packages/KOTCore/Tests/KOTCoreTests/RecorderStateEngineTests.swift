import Foundation
import Testing
@testable import KOTCore

@Suite struct RecorderStateEngineTests {
    private let today = "20260610"

    private func entry(_ name: String, _ timestamp: String) -> RecordHistoryEntry {
        RecordHistoryEntry(name: name, sendTimestamp: timestamp)
    }

    @Test func filtersToToday() {
        // 履歴は新しい順（index 0 が最新）
        let history = [
            entry("出勤", "20260610090000"),
            entry("退勤", "20260609180000"),
            entry("出勤", "20260609090000"),
        ]
        let state = RecorderStateEngine.state(history: history, today: today)
        #expect(state.isClockedIn)
        #expect(!state.isClockedOut)
        #expect(state.todayRecords.count == 1)
    }

    @Test func onBreakWhenNewestIsBreakStart() {
        let history = [
            entry("休始", "20260610120000"),
            entry("出勤", "20260610090000"),
        ]
        let state = RecorderStateEngine.state(history: history, today: today)
        #expect(state.onBreak)
        #expect(state.isClockedIn)
    }

    @Test func notOnBreakAfterBreakEnd() {
        let history = [
            entry("休終", "20260610130000"),
            entry("休始", "20260610120000"),
            entry("出勤", "20260610090000"),
        ]
        let state = RecorderStateEngine.state(history: history, today: today)
        #expect(!state.onBreak)
    }

    @Test func yesterdayBreakDoesNotLeak() {
        // 前日の最後が休始でも、当日履歴が空なら休憩中ではない
        let history = [entry("休始", "20260609120000")]
        let state = RecorderStateEngine.state(history: history, today: today)
        #expect(!state.onBreak)
        #expect(!state.isClockedIn)
        #expect(state.todayRecords.isEmpty)
    }

    @Test func emptyHistory() {
        let state = RecorderStateEngine.state(history: [], today: today)
        #expect(state == RecorderState(isClockedIn: false, isClockedOut: false, onBreak: false, todayRecords: []))
    }

    // ボタン可用性マトリクス（inject.js の減光ルールの裏返し）

    @Test func availabilityBeforeClockIn() {
        let state = RecorderStateEngine.state(history: [], today: today)
        #expect(RecorderStateEngine.isActionAvailable(.clockIn, state: state))
        #expect(RecorderStateEngine.isActionAvailable(.clockOut, state: state))
        #expect(!RecorderStateEngine.isActionAvailable(.breakStart, state: state))
        #expect(!RecorderStateEngine.isActionAvailable(.breakEnd, state: state))
    }

    @Test func availabilityWhileWorking() {
        let state = RecorderStateEngine.state(history: [entry("出勤", "20260610090000")], today: today)
        #expect(!RecorderStateEngine.isActionAvailable(.clockIn, state: state))
        #expect(RecorderStateEngine.isActionAvailable(.clockOut, state: state))
        #expect(RecorderStateEngine.isActionAvailable(.breakStart, state: state))
        #expect(!RecorderStateEngine.isActionAvailable(.breakEnd, state: state))
    }

    @Test func availabilityOnBreak() {
        let state = RecorderStateEngine.state(
            history: [entry("休始", "20260610120000"), entry("出勤", "20260610090000")],
            today: today
        )
        #expect(!RecorderStateEngine.isActionAvailable(.clockIn, state: state))
        // 休憩中は退勤不可（原拡張は休憩中に退勤ボタンを減光する）
        #expect(!RecorderStateEngine.isActionAvailable(.clockOut, state: state))
        #expect(!RecorderStateEngine.isActionAvailable(.breakStart, state: state))
        #expect(RecorderStateEngine.isActionAvailable(.breakEnd, state: state))
    }

    @Test func availabilityAfterClockOut() {
        let state = RecorderStateEngine.state(
            history: [entry("退勤", "20260610180000"), entry("出勤", "20260610090000")],
            today: today
        )
        #expect(!RecorderStateEngine.isActionAvailable(.clockIn, state: state))
        #expect(!RecorderStateEngine.isActionAvailable(.clockOut, state: state))
        #expect(!RecorderStateEngine.isActionAvailable(.breakStart, state: state))
        #expect(!RecorderStateEngine.isActionAvailable(.breakEnd, state: state))
    }

    @Test func dayStampFormatting() {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 5
        components.hour = 12
        var calendar = Calendar(identifier: .gregorian)
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        calendar.timeZone = tokyo
        let date = calendar.date(from: components)!
        #expect(RecorderStateEngine.dayStamp(for: date, timeZone: tokyo) == "20260605")
    }
}
