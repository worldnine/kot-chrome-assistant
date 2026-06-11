import Foundation
import Testing
@testable import KOTCore

@Suite struct TimecardParserTests {
    /// 実際のタイムカード画面（monthly_individual_working_list）の構造を模したフィクスチャ
    private func timecardHTML(
        date: String,
        start: String,
        end: String,
        restStart: String = "",
        restEnd: String = ""
    ) -> String {
        func dayRow(date: String, start: String, end: String, restStart: String, restEnd: String) -> String {
            """
            <td data-ht-identity-cell="specific-sidemenu_date" class="htBlock-scrollTable_day " title="" data-ht-sort-index="WORK_DAY" >
              <p> \(date) </p>
            </td>
            <td class="schedule specific-timecard_schedule " data-ht-sort-index="SCHEDULE" ><p> 裁量労働制 </p></td>
            <td class="work_day_type " data-ht-sort-index="WORK_DAY_TYPE" ><p> 平日</p></td>
            <td class="start_end_timerecord " data-ht-sort-index="START_TIMERECORD" >
              <p> \(start) </p>
            </td>
            <td class="start_end_timerecord " data-ht-sort-index="END_TIMERECORD" >
              <p> \(end) </p>
            </td>
            <td class="rest_timerecord " data-ht-sort-index="REST_START_TIMERECORD" >
              <p> \(restStart) </p>
            </td>
            <td class="rest_timerecord " data-ht-sort-index="REST_END_TIMERECORD" >
              <p> \(restEnd) </p>
            </td>
            """
        }
        // 前日（満了済み）の行 + 当日の行。ヘッダにも sort-index が現れる構造を再現
        return """
        <html><body>
        <th data-ht-sort-index="START_TIMERECORD">出勤</th>
        <th data-ht-sort-index="END_TIMERECORD">退勤</th>
        <table>
        \(dayRow(date: "06/10（水）", start: "09:00", end: "18:00", restStart: "12:00", restEnd: "13:00"))
        \(dayRow(date: date, start: start, end: end, restStart: restStart, restEnd: restEnd))
        </table>
        </body></html>
        """
    }

    private let day = "20260611"

    @Test func clockedInOnly() throws {
        let html = timecardHTML(date: "06/11（木）", start: #"<span class="specific-edited_record_sign">編</span> 10:00<br>"#, end: "")
        let state = try TimecardParser.state(html: html, dayStamp: day)
        #expect(state.isClockedIn)
        #expect(!state.isClockedOut)
        #expect(!state.onBreak)
        #expect(state.todayRecords == [.init(action: .clockIn, timestamp: "20260611100000")])
    }

    @Test func onBreak() throws {
        let html = timecardHTML(date: "06/11（木）", start: "9:30", end: "", restStart: "12:00", restEnd: "")
        let state = try TimecardParser.state(html: html, dayStamp: day)
        #expect(state.isClockedIn)
        #expect(state.onBreak)
        // 1桁時はゼロ埋めされ、新しい順に並ぶ
        #expect(state.todayRecords.map(\.timestamp) == ["20260611120000", "20260611093000"])
    }

    @Test func multipleBreaksAllFinished() throws {
        let html = timecardHTML(
            date: "06/11（木）", start: "09:00", end: "",
            restStart: "12:00<br>15:00", restEnd: "13:00<br>15:30"
        )
        let state = try TimecardParser.state(html: html, dayStamp: day)
        #expect(!state.onBreak)
        #expect(state.todayRecords.count == 5)
    }

    @Test func clockedOut() throws {
        let html = timecardHTML(date: "06/11（木）", start: "09:00", end: "18:30")
        let state = try TimecardParser.state(html: html, dayStamp: day)
        #expect(state.isClockedIn)
        #expect(state.isClockedOut)
        #expect(!state.onBreak)
        #expect(state.phase == .finished)
    }

    @Test func reClockInAfterClockOut() throws {
        // 退勤 18:00 のあと 19:00 に再出勤 → 最新イベント基準で勤務中
        let html = timecardHTML(date: "06/11（木）", start: "10:00<br>19:00", end: "18:00")
        let state = try TimecardParser.state(html: html, dayStamp: day)
        #expect(state.phase == .working)
        #expect(state.todayRecords.first == .init(action: .clockIn, timestamp: "20260611190000"))
    }

    @Test func sameMinuteClockOutAndReClockIn() throws {
        // タイムカードは分単位。同じ分の退勤と再出勤は勤務中とみなす
        let html = timecardHTML(date: "06/11（木）", start: "10:00<br>18:00", end: "18:00")
        let state = try TimecardParser.state(html: html, dayStamp: day)
        #expect(state.phase == .working)
    }

    @Test func noPunchesToday() throws {
        let state = try TimecardParser.state(
            html: timecardHTML(date: "06/11（木）", start: "", end: ""),
            dayStamp: day
        )
        #expect(state == RecorderState(isClockedIn: false, isClockedOut: false, onBreak: false, todayRecords: []))
    }

    @Test func previousDayDoesNotLeakIntoToday() throws {
        // 前日の行（09:00-18:00）があっても、当日行（空）だけを読む
        let html = timecardHTML(date: "06/11（木）", start: "", end: "")
        let state = try TimecardParser.state(html: html, dayStamp: day)
        #expect(!state.isClockedIn)
    }

    @Test func missingTodayRowThrows() {
        let html = timecardHTML(date: "06/12（金）", start: "09:00", end: "")
        #expect(throws: TimecardParser.ParseError.todayRowNotFound) {
            try TimecardParser.state(html: html, dayStamp: day)
        }
    }
}
