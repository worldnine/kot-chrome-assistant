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

    /// 現在のフェーズ。**最新の打刻イベント**で決まる（退勤後の再出勤も正しく勤務中になる）。
    /// isClockedIn / isClockedOut は「その打刻が当日存在するか」という生の事実で、
    /// 現在状態の表示・可否判定にはこちらを使うこと。
    public var phase: WorkPhase {
        guard let latest = todayRecords.first else { return .notStarted }
        switch latest.action {
        case .clockIn, .breakEnd: return .working
        case .breakStart: return .onBreak
        case .clockOut: return .finished
        }
    }
}

/// 当日の勤務フェーズ
public enum WorkPhase: Equatable, Sendable {
    case notStarted
    case working
    case onBreak
    case finished
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

    /// アクションの可用性（UI ではボタン減光、打刻時は警告の判定に使う）。
    /// フェーズ基準: 退勤後の再出勤も可。
    public static func isActionAvailable(_ action: PunchAction, state: RecorderState) -> Bool {
        switch (state.phase, action) {
        case (.notStarted, .clockIn), (.finished, .clockIn):
            return true
        case (.working, .clockOut), (.working, .breakStart):
            return true
        case (.onBreak, .breakEnd):
            return true
        default:
            return false
        }
    }
}
