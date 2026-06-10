import Foundation

/// 打刻アクション。KING OF TIME の打刻履歴上の名称と 1:1 で対応する。
public enum PunchAction: String, CaseIterable, Codable, Sendable {
    case clockIn
    case clockOut
    case breakStart
    case breakEnd

    /// KOT の RECORD_HISTORY に記録されるアクション名
    public var kotName: String {
        switch self {
        case .clockIn: return "出勤"
        case .clockOut: return "退勤"
        case .breakStart: return "休始"
        case .breakEnd: return "休終"
        }
    }

    public init?(kotName: String) {
        guard let action = Self.allCases.first(where: { $0.kotName == kotName }) else { return nil }
        self = action
    }

    public var displayName: String { kotName }
}
