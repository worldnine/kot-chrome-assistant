import Foundation

/// 設定値の永続化先（UserDefaults / テスト用インメモリ）
public protocol KeyValueStore: Sendable {
    func string(forKey key: String) -> String?
    func bool(forKey key: String) -> Bool
    func set(_ value: String, forKey key: String)
    func set(_ value: Bool, forKey key: String)
    func removeValue(forKey key: String)
}

public final class InMemoryKeyValueStore: KeyValueStore, @unchecked Sendable {
    private var storage: [String: Any] = [:]
    private let lock = NSLock()

    public init() {}

    public func string(forKey key: String) -> String? {
        lock.withLock { storage[key] as? String }
    }

    public func bool(forKey key: String) -> Bool {
        lock.withLock { storage[key] as? Bool ?? false }
    }

    public func set(_ value: String, forKey key: String) {
        lock.withLock { storage[key] = value }
    }

    public func set(_ value: Bool, forKey key: String) {
        lock.withLock { storage[key] = value }
    }

    public func removeValue(forKey key: String) {
        _ = lock.withLock { storage.removeValue(forKey: key) }
    }
}

/// UserDefaults ラッパー（UserDefaults 自体はスレッドセーフ）
public struct UserDefaultsStore: KeyValueStore, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func string(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    public func bool(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    public func set(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func set(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    public func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}

/// AppSettings ↔ KeyValueStore の変換。
/// キー名は Chrome 拡張の chrome.storage.sync のキーを踏襲する
/// （旧 s2/s3/s4Selected・samlSelected は kotDomain / kotAuthMode に集約）。
public struct SettingsStore: Sendable {
    private let store: KeyValueStore

    public init(store: KeyValueStore) {
        self.store = store
    }

    private enum Key {
        static let debuggable = "debuggable"

        static let slackEnabled = "slackEnabled"
        static let slackChannel = "slackChannel"
        static let slackClockInMessage = "slackClockInMessage"
        static let slackClockOutMessage = "slackClockOutMessage"
        static let slackTakeABreakMessage = "slackTakeABreakMessage"
        static let slackBreakIsOverMessage = "slackBreakIsOverMessage"
        static let slackApiType = "slackApiType"
        static let slackWebHooksUrl = "slackWebHooksUrl"

        static let slackStatusEnabled = "slackStatusEnabled"
        static let slackClockInStatusEmoji = "slackClockInStatusEmoji"
        static let slackClockInStatusText = "slackClockInStatusText"
        static let slackClockOutStatusEmoji = "slackClockOutStatusEmoji"
        static let slackClockOutStatusText = "slackClockOutStatusText"
        static let slackTakeABreakStatusEmoji = "slackTakeABreakStatusEmoji"
        static let slackTakeABreakStatusText = "slackTakeABreakStatusText"

        static let googleChatEnabled = "googleChatEnabled"
        static let googleChatWebhooksUrl = "googleChatWebhooksUrl"
        static let googleChatClockInMessage = "googleChatClockInMessage"
        static let googleChatClockOutMessage = "googleChatClockOutMessage"
        static let googleChatTakeABreakMessage = "googleChatTakeABreakMessage"
        static let googleChatBreakIsOverMessage = "googleChatBreakIsOverMessage"

        static let googleChatUserEnabled = "googleChatUserEnabled"
        static let googleChatOAuthClientId = "googleChatOAuthClientId"
        static let googleChatUserSpace = "googleChatUserSpace"
        static let googleChatUserClockInMessage = "googleChatUserClockInMessage"
        static let googleChatUserClockOutMessage = "googleChatUserClockOutMessage"
        static let googleChatUserTakeABreakMessage = "googleChatUserTakeABreakMessage"
        static let googleChatUserBreakIsOverMessage = "googleChatUserBreakIsOverMessage"

        static let kotDomain = "kotDomain"
        static let kotAuthMode = "kotAuthMode"
    }

    public func load() -> AppSettings {
        AppSettings(
            slackMessage: SlackMessageSettings(
                enabled: store.bool(forKey: Key.slackEnabled),
                channels: list(Key.slackChannel),
                apiType: SlackMessageSettings.APIType(rawValue: store.string(forKey: Key.slackApiType) ?? "") ?? .asUser,
                webhookURLs: list(Key.slackWebHooksUrl),
                clockInMessage: string(Key.slackClockInMessage),
                clockOutMessage: string(Key.slackClockOutMessage),
                breakStartMessage: string(Key.slackTakeABreakMessage),
                breakEndMessage: string(Key.slackBreakIsOverMessage)
            ),
            slackStatus: SlackStatusSettings(
                enabled: store.bool(forKey: Key.slackStatusEnabled),
                clockIn: .init(emoji: string(Key.slackClockInStatusEmoji), text: string(Key.slackClockInStatusText)),
                clockOut: .init(emoji: string(Key.slackClockOutStatusEmoji), text: string(Key.slackClockOutStatusText)),
                breakStart: .init(emoji: string(Key.slackTakeABreakStatusEmoji), text: string(Key.slackTakeABreakStatusText))
            ),
            googleChatWebhook: GoogleChatWebhookSettings(
                enabled: store.bool(forKey: Key.googleChatEnabled),
                webhookURLs: list(Key.googleChatWebhooksUrl),
                clockInMessage: string(Key.googleChatClockInMessage),
                clockOutMessage: string(Key.googleChatClockOutMessage),
                breakStartMessage: string(Key.googleChatTakeABreakMessage),
                breakEndMessage: string(Key.googleChatBreakIsOverMessage)
            ),
            googleChatUser: GoogleChatUserSettings(
                enabled: store.bool(forKey: Key.googleChatUserEnabled),
                oauthClientID: string(Key.googleChatOAuthClientId),
                spaces: list(Key.googleChatUserSpace),
                clockInMessage: string(Key.googleChatUserClockInMessage),
                clockOutMessage: string(Key.googleChatUserClockOutMessage),
                breakStartMessage: string(Key.googleChatUserTakeABreakMessage),
                breakEndMessage: string(Key.googleChatUserBreakIsOverMessage)
            ),
            recorder: RecorderSettings(
                domain: KOTDomain(rawValue: store.string(forKey: Key.kotDomain) ?? "") ?? .s2,
                authMode: KOTAuthMode(rawValue: store.string(forKey: Key.kotAuthMode) ?? "") ?? .account
            ),
            debugLogging: store.bool(forKey: Key.debuggable)
        )
    }

    public func save(_ settings: AppSettings) {
        store.set(settings.slackMessage.enabled, forKey: Key.slackEnabled)
        store.set(settings.slackMessage.channels.joined(separator: " "), forKey: Key.slackChannel)
        store.set(settings.slackMessage.apiType.rawValue, forKey: Key.slackApiType)
        store.set(settings.slackMessage.webhookURLs.joined(separator: " "), forKey: Key.slackWebHooksUrl)
        store.set(settings.slackMessage.clockInMessage, forKey: Key.slackClockInMessage)
        store.set(settings.slackMessage.clockOutMessage, forKey: Key.slackClockOutMessage)
        store.set(settings.slackMessage.breakStartMessage, forKey: Key.slackTakeABreakMessage)
        store.set(settings.slackMessage.breakEndMessage, forKey: Key.slackBreakIsOverMessage)

        store.set(settings.slackStatus.enabled, forKey: Key.slackStatusEnabled)
        store.set(settings.slackStatus.clockIn.emoji, forKey: Key.slackClockInStatusEmoji)
        store.set(settings.slackStatus.clockIn.text, forKey: Key.slackClockInStatusText)
        store.set(settings.slackStatus.clockOut.emoji, forKey: Key.slackClockOutStatusEmoji)
        store.set(settings.slackStatus.clockOut.text, forKey: Key.slackClockOutStatusText)
        store.set(settings.slackStatus.breakStart.emoji, forKey: Key.slackTakeABreakStatusEmoji)
        store.set(settings.slackStatus.breakStart.text, forKey: Key.slackTakeABreakStatusText)

        store.set(settings.googleChatWebhook.enabled, forKey: Key.googleChatEnabled)
        store.set(settings.googleChatWebhook.webhookURLs.joined(separator: " "), forKey: Key.googleChatWebhooksUrl)
        store.set(settings.googleChatWebhook.clockInMessage, forKey: Key.googleChatClockInMessage)
        store.set(settings.googleChatWebhook.clockOutMessage, forKey: Key.googleChatClockOutMessage)
        store.set(settings.googleChatWebhook.breakStartMessage, forKey: Key.googleChatTakeABreakMessage)
        store.set(settings.googleChatWebhook.breakEndMessage, forKey: Key.googleChatBreakIsOverMessage)

        store.set(settings.googleChatUser.enabled, forKey: Key.googleChatUserEnabled)
        store.set(settings.googleChatUser.oauthClientID, forKey: Key.googleChatOAuthClientId)
        store.set(settings.googleChatUser.spaces.joined(separator: " "), forKey: Key.googleChatUserSpace)
        store.set(settings.googleChatUser.clockInMessage, forKey: Key.googleChatUserClockInMessage)
        store.set(settings.googleChatUser.clockOutMessage, forKey: Key.googleChatUserClockOutMessage)
        store.set(settings.googleChatUser.breakStartMessage, forKey: Key.googleChatUserTakeABreakMessage)
        store.set(settings.googleChatUser.breakEndMessage, forKey: Key.googleChatUserBreakIsOverMessage)

        store.set(settings.recorder.domain.rawValue, forKey: Key.kotDomain)
        store.set(settings.recorder.authMode.rawValue, forKey: Key.kotAuthMode)

        store.set(settings.debugLogging, forKey: Key.debuggable)
    }

    private func string(_ key: String) -> String {
        store.string(forKey: key) ?? ""
    }

    private func list(_ key: String) -> [String] {
        (store.string(forKey: key) ?? "")
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
