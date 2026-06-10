import AppIntents
import Foundation
import KOTCore

/// 打刻インテント共通処理
@MainActor
private func performPunch(_ action: PunchAction, recorder: RecorderWebController) async throws -> IntentDialog {
    _ = try await recorder.punch(action)
    return IntentDialog("\(action.displayName)を打刻しました")
}

struct PunchInIntent: AppIntent {
    static let title: LocalizedStringResource = "出勤"
    static let description = IntentDescription("KING OF TIME に出勤を打刻します")

    @Dependency private var recorder: RecorderWebController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: try await performPunch(.clockIn, recorder: recorder))
    }
}

struct PunchOutIntent: AppIntent {
    static let title: LocalizedStringResource = "退勤"
    static let description = IntentDescription("KING OF TIME に退勤を打刻します")

    @Dependency private var recorder: RecorderWebController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: try await performPunch(.clockOut, recorder: recorder))
    }
}

struct StartBreakIntent: AppIntent {
    static let title: LocalizedStringResource = "休憩開始"
    static let description = IntentDescription("KING OF TIME に休憩開始を打刻します")

    @Dependency private var recorder: RecorderWebController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: try await performPunch(.breakStart, recorder: recorder))
    }
}

struct EndBreakIntent: AppIntent {
    static let title: LocalizedStringResource = "休憩終了"
    static let description = IntentDescription("KING OF TIME に休憩終了を打刻します")

    @Dependency private var recorder: RecorderWebController

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: try await performPunch(.breakEnd, recorder: recorder))
    }
}

struct GetPunchStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "打刻状況"
    static let description = IntentDescription("今日の打刻状況を取得します")

    @Dependency private var recorder: RecorderWebController

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let state = try await recorder.currentState()
        let summary = Self.summary(of: state)
        return .result(value: summary, dialog: IntentDialog("\(summary)"))
    }

    static func summary(of state: RecorderState) -> String {
        let headline: String
        if state.onBreak {
            headline = "休憩中"
        } else if state.isClockedOut {
            headline = "退勤済み"
        } else if state.isClockedIn {
            headline = "勤務中"
        } else {
            headline = "未出勤"
        }

        // 当日履歴は新しい順なので時系列に直して並べる
        let records = state.todayRecords.reversed().map { record in
            "\(record.action.displayName) \(formatTime(record.timestamp))"
        }
        guard !records.isEmpty else { return headline }
        return "\(headline)（\(records.joined(separator: " → "))）"
    }

    /// `YYYYMMDDHHMMSS` → `HH:MM`
    private static func formatTime(_ timestamp: String) -> String {
        guard timestamp.count >= 12 else { return timestamp }
        let hour = timestamp.dropFirst(8).prefix(2)
        let minute = timestamp.dropFirst(10).prefix(2)
        return "\(hour):\(minute)"
    }
}
