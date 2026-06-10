import Foundation

/// レコーダーページの localStorage `PARSONAL_BROWSER_RECORDER@SETTING` のデコード結果。
/// 必要なフィールドのみ取り出す。
public struct RecorderSetting: Decodable, Sendable {
    public struct User: Decodable, Sendable {
        public let userToken: String

        enum CodingKeys: String, CodingKey {
            case userToken = "user_token"
        }
    }

    public struct RecordButton: Decodable, Sendable {
        public let id: String
        /// '1'=出勤, '2'=退勤, '0'=休憩（休始・休終の2つ）
        public let mark: String

        public init(id: String, mark: String) {
            self.id = id
            self.mark = mark
        }
    }

    public struct TimeRecorder: Decodable, Sendable {
        public let recordButton: [RecordButton]

        enum CodingKeys: String, CodingKey {
            case recordButton = "record_button"
        }
    }

    public let user: User
    public let timerecorder: TimeRecorder

    public init(json: Data) throws {
        self = try JSONDecoder().decode(RecorderSetting.self, from: json)
    }

    /// mark からの打刻ボタン解決。休憩は mark '0' の出現順で 休始 → 休終。
    public func buttonID(for action: PunchAction) -> String? {
        let buttons = timerecorder.recordButton
        switch action {
        case .clockIn: return buttons.first { $0.mark == "1" }?.id
        case .clockOut: return buttons.first { $0.mark == "2" }?.id
        case .breakStart: return buttons.filter { $0.mark == "0" }.first?.id
        case .breakEnd:
            let breaks = buttons.filter { $0.mark == "0" }
            return breaks.count >= 2 ? breaks[1].id : nil
        }
    }
}

/// localStorage `PARSONAL_BROWSER_RECORDER@RECORD_HISTORY_<user_token>` の 1 レコード。
/// 配列は新しい順（index 0 が最新）で格納されている。
public struct RecordHistoryEntry: Decodable, Sendable {
    public let name: String
    /// `YYYYMMDDHHMMSS`
    public let sendTimestamp: String

    enum CodingKeys: String, CodingKey {
        case name
        case sendTimestamp = "send_timestamp"
    }

    public init(name: String, sendTimestamp: String) {
        self.name = name
        self.sendTimestamp = sendTimestamp
    }

    public var action: PunchAction? { PunchAction(kotName: name) }
}

public enum RecordHistory {
    public static func decode(json: Data) throws -> [RecordHistoryEntry] {
        try JSONDecoder().decode([RecordHistoryEntry].self, from: json)
    }
}

/// WebView から取得した localStorage のスナップショット
public struct RecorderSnapshot: Sendable {
    public let setting: RecorderSetting
    /// 新しい順
    public let history: [RecordHistoryEntry]

    public init(setting: RecorderSetting, history: [RecordHistoryEntry]) {
        self.setting = setting
        self.history = history
    }

    public init(settingJSON: Data, historyJSON: Data?) throws {
        self.setting = try RecorderSetting(json: settingJSON)
        self.history = try historyJSON.map { try RecordHistory.decode(json: $0) } ?? []
    }
}
