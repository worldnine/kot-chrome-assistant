import Foundation

/// Slack メッセージ通知設定
public struct SlackMessageSettings: Equatable, Codable, Sendable {
    public enum APIType: String, Codable, Sendable {
        case asUser
        case incomingWebhook = "IncomingWebHooks"
    }

    public var enabled: Bool
    /// 投稿先チャンネル（複数ワークスペース/チャンネル対応）
    public var channels: [String]
    public var apiType: APIType
    /// asUser モードのトークン。1個なら全チャンネル共通、複数ならチャンネルと同順で対応
    /// （トークン自体は Keychain。ここには持たない）
    public var webhookURLs: [String]
    public var clockInMessage: String
    public var clockOutMessage: String
    public var breakStartMessage: String
    public var breakEndMessage: String

    public init(
        enabled: Bool = false,
        channels: [String] = [],
        apiType: APIType = .asUser,
        webhookURLs: [String] = [],
        clockInMessage: String = "",
        clockOutMessage: String = "",
        breakStartMessage: String = "",
        breakEndMessage: String = ""
    ) {
        self.enabled = enabled
        self.channels = channels
        self.apiType = apiType
        self.webhookURLs = webhookURLs
        self.clockInMessage = clockInMessage
        self.clockOutMessage = clockOutMessage
        self.breakStartMessage = breakStartMessage
        self.breakEndMessage = breakEndMessage
    }

    public func message(for action: PunchAction) -> String {
        switch action {
        case .clockIn: return clockInMessage
        case .clockOut: return clockOutMessage
        case .breakStart: return breakStartMessage
        case .breakEnd: return breakEndMessage
        }
    }
}

/// Slack ステータス更新設定
public struct SlackStatusSettings: Equatable, Codable, Sendable {
    public struct Status: Equatable, Codable, Sendable {
        public var emoji: String
        public var text: String

        public init(emoji: String = "", text: String = "") {
            self.emoji = emoji
            self.text = text
        }
    }

    public var enabled: Bool
    public var clockIn: Status
    public var clockOut: Status
    public var breakStart: Status

    public init(
        enabled: Bool = false,
        clockIn: Status = Status(),
        clockOut: Status = Status(),
        breakStart: Status = Status()
    ) {
        self.enabled = enabled
        self.clockIn = clockIn
        self.clockOut = clockOut
        self.breakStart = breakStart
    }

    /// 休憩終了は出勤時のステータスに戻す（原拡張と同じ）
    public func status(for action: PunchAction) -> Status {
        switch action {
        case .clockIn, .breakEnd: return clockIn
        case .clockOut: return clockOut
        case .breakStart: return breakStart
        }
    }
}

/// Google Chat Webhook 通知設定
public struct GoogleChatWebhookSettings: Equatable, Codable, Sendable {
    public var enabled: Bool
    public var webhookURLs: [String]
    public var clockInMessage: String
    public var clockOutMessage: String
    public var breakStartMessage: String
    public var breakEndMessage: String

    public init(
        enabled: Bool = false,
        webhookURLs: [String] = [],
        clockInMessage: String = "",
        clockOutMessage: String = "",
        breakStartMessage: String = "",
        breakEndMessage: String = ""
    ) {
        self.enabled = enabled
        self.webhookURLs = webhookURLs
        self.clockInMessage = clockInMessage
        self.clockOutMessage = clockOutMessage
        self.breakStartMessage = breakStartMessage
        self.breakEndMessage = breakEndMessage
    }

    public func message(for action: PunchAction) -> String {
        switch action {
        case .clockIn: return clockInMessage
        case .clockOut: return clockOutMessage
        case .breakStart: return breakStartMessage
        case .breakEnd: return breakEndMessage
        }
    }
}

/// Google Chat ユーザー認証（OAuth2）通知設定
public struct GoogleChatUserSettings: Equatable, Codable, Sendable {
    public var enabled: Bool
    public var oauthClientID: String
    /// スペース ID（正規化前の入力を保持。送信時に SpaceID.normalize する）
    public var spaces: [String]
    public var clockInMessage: String
    public var clockOutMessage: String
    public var breakStartMessage: String
    public var breakEndMessage: String

    public init(
        enabled: Bool = false,
        oauthClientID: String = "",
        spaces: [String] = [],
        clockInMessage: String = "",
        clockOutMessage: String = "",
        breakStartMessage: String = "",
        breakEndMessage: String = ""
    ) {
        self.enabled = enabled
        self.oauthClientID = oauthClientID
        self.spaces = spaces
        self.clockInMessage = clockInMessage
        self.clockOutMessage = clockOutMessage
        self.breakStartMessage = breakStartMessage
        self.breakEndMessage = breakEndMessage
    }

    public func message(for action: PunchAction) -> String {
        switch action {
        case .clockIn: return clockInMessage
        case .clockOut: return clockOutMessage
        case .breakStart: return breakStartMessage
        case .breakEnd: return breakEndMessage
        }
    }
}

/// レコーダー接続設定
public struct RecorderSettings: Equatable, Codable, Sendable {
    public var domain: KOTDomain
    public var authMode: KOTAuthMode

    public init(domain: KOTDomain = .s2, authMode: KOTAuthMode = .account) {
        self.domain = domain
        self.authMode = authMode
    }

    public var url: URL { RecorderPage.url(domain: domain, authMode: authMode) }
}

/// アプリ全設定（シークレットを除く）
public struct AppSettings: Equatable, Codable, Sendable {
    public var slackMessage: SlackMessageSettings
    public var slackStatus: SlackStatusSettings
    public var googleChatWebhook: GoogleChatWebhookSettings
    public var googleChatUser: GoogleChatUserSettings
    public var recorder: RecorderSettings
    public var debugLogging: Bool

    public init(
        slackMessage: SlackMessageSettings = SlackMessageSettings(),
        slackStatus: SlackStatusSettings = SlackStatusSettings(),
        googleChatWebhook: GoogleChatWebhookSettings = GoogleChatWebhookSettings(),
        googleChatUser: GoogleChatUserSettings = GoogleChatUserSettings(),
        recorder: RecorderSettings = RecorderSettings(),
        debugLogging: Bool = false
    ) {
        self.slackMessage = slackMessage
        self.slackStatus = slackStatus
        self.googleChatWebhook = googleChatWebhook
        self.googleChatUser = googleChatUser
        self.recorder = recorder
        self.debugLogging = debugLogging
    }
}
