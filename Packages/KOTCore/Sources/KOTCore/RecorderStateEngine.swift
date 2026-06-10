import Foundation

/// 当日の打刻状態
public struct RecorderState: Equatable, Sendable {
    public let isClockedIn: Bool
    public let isClockedOut: Bool
    /// 最新の打刻が「休始」（休憩中）
    public let onBreak: Bool
    /// 当日分の履歴（新しい順）
    public let todayRecords: [PunchRecord]

    public struct PunchRecord: Equatable, Sendable {
        public let action: PunchAction
        /// `YYYYMMDDHHMMSS`
        public let timestamp: String

        public init(action: PunchAction, timestamp: String) {
            self.action = action
            self.timestamp = timestamp
        }
    }

    public init(isClockedIn: Bool, isClockedOut: Bool, onBreak: Bool, todayRecords: [PunchRecord]) {
        self.isClockedIn = isClockedIn
        self.isClockedOut = isClockedOut
        self.onBreak = onBreak
        self.todayRecords = todayRecords
    }
}

public enum RecorderStateEngine {
    /// `YYYYMMDD`（ローカルタイムゾーン基準。原拡張の new Date() と同じ扱い）
    public static func dayStamp(for date: Date = Date(), timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year!, c.month!, c.day!)
    }

    /// 履歴（新しい順）から当日の打刻状態を導出する。
    public static func state(history: [RecordHistoryEntry], today: String) -> RecorderState {
        let todayEntries = history.filter { $0.sendTimestamp.hasPrefix(today) }
        let records = todayEntries.compactMap { entry in
            entry.action.map { RecorderState.PunchRecord(action: $0, timestamp: entry.sendTimestamp) }
        }
        return RecorderState(
            isClockedIn: todayEntries.contains { $0.name == PunchAction.clockIn.kotName },
            isClockedOut: todayEntries.contains { $0.name == PunchAction.clockOut.kotName },
            onBreak: todayEntries.first?.name == PunchAction.breakStart.kotName,
            todayRecords: records
        )
    }

    /// ボタンの可用性（原拡張は不可ボタンを opacity 0.3 に減光する）。
    /// inject.js の減光ロジックの裏返し。
    public static func isActionAvailable(_ action: PunchAction, state: RecorderState) -> Bool {
        switch action {
        case .clockIn:
            return !state.isClockedIn
        case .clockOut:
            return !state.isClockedOut && !state.onBreak
        case .breakStart:
            return state.isClockedIn && !state.isClockedOut && !state.onBreak
        case .breakEnd:
            return state.onBreak
        }
    }
}
