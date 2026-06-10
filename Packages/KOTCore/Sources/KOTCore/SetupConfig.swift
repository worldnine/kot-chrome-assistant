import Foundation

/// セットアップ URL（`#setup=BASE64(JSON)` / `kotassistant://setup?d=BASE64`）の取り込み。
/// Google Chat ユーザー認証の設定を配布するための仕組み。
public struct SetupConfig: Decodable, Equatable, Sendable {
    public var clientId: String?
    public var clientSecret: String?
    /// スペース ID（スペース区切りで複数可）
    public var space: String?
    public var clockIn: String?
    public var clockOut: String?
    public var breakStart: String?
    public var breakEnd: String?

    public init(
        clientId: String? = nil,
        clientSecret: String? = nil,
        space: String? = nil,
        clockIn: String? = nil,
        clockOut: String? = nil,
        breakStart: String? = nil,
        breakEnd: String? = nil
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.space = space
        self.clockIn = clockIn
        self.clockOut = clockOut
        self.breakStart = breakStart
        self.breakEnd = breakEnd
    }

    /// メッセージの既定値（原拡張の GCHAT_DEFAULTS）
    public enum Defaults {
        public static let clockIn = "出社しました。"
        public static let clockOut = "退社します。"
        public static let breakStart = "休憩入ります。"
        public static let breakEnd = "再開します。"
    }

    public enum ParseError: Error, Equatable {
        case noSetupPayload
        case invalidBase64
        case invalidJSON
    }

    /// 受け付ける入力:
    /// - 旧拡張のオプションページ URL `...#setup=BASE64`
    /// - `kotassistant://setup?d=BASE64`
    /// - 素の BASE64 文字列
    public static func parse(_ input: String) throws -> SetupConfig {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let base64: String
        if let range = trimmed.range(of: "#setup=") {
            base64 = String(trimmed[range.upperBound...])
        } else if let url = URL(string: trimmed), url.scheme == "kotassistant" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let d = components.queryItems?.first(where: { $0.name == "d" })?.value, !d.isEmpty else {
                throw ParseError.noSetupPayload
            }
            base64 = d
        } else if !trimmed.isEmpty {
            base64 = trimmed
        } else {
            throw ParseError.noSetupPayload
        }

        guard let data = Data(base64Encoded: padded(base64)) else {
            throw ParseError.invalidBase64
        }
        guard let config = try? JSONDecoder().decode(SetupConfig.self, from: data) else {
            throw ParseError.invalidJSON
        }
        return config
    }

    /// URL エンコードで `=` が落ちた base64 のパディング補完
    private static func padded(_ base64: String) -> String {
        let remainder = base64.count % 4
        guard remainder > 0 else { return base64 }
        return base64 + String(repeating: "=", count: 4 - remainder)
    }

    /// マージ規則（原拡張の processSetupUrl と同一）:
    /// URL の値 > 既存の値 > 既定値。スペースは追加式（既存保持・重複排除）。連携は自動で有効化。
    public func apply(to settings: inout GoogleChatUserSettings) {
        var spaces = settings.spaces
        if let space {
            for s in space.split(separator: " ").map(String.init) where !s.isEmpty && !spaces.contains(s) {
                spaces.append(s)
            }
        }

        settings.enabled = true
        settings.oauthClientID = firstNonEmpty(clientId, settings.oauthClientID) ?? ""
        settings.spaces = spaces
        settings.clockInMessage = firstNonEmpty(clockIn, settings.clockInMessage) ?? Defaults.clockIn
        settings.clockOutMessage = firstNonEmpty(clockOut, settings.clockOutMessage) ?? Defaults.clockOut
        settings.breakStartMessage = firstNonEmpty(breakStart, settings.breakStartMessage) ?? Defaults.breakStart
        settings.breakEndMessage = firstNonEmpty(breakEnd, settings.breakEndMessage) ?? Defaults.breakEnd
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values where value?.isEmpty == false {
            return value
        }
        return nil
    }
}
