import Foundation

/// Keychain に保存するシークレットのキー。
/// gchat 系は Chrome 拡張の chrome.storage.local のキー（_gchat*）に対応する。
public enum SecretKey: String, CaseIterable, Sendable {
    case slackToken
    case slackStatusToken
    case googleChatOAuthClientSecret
    case gchatAccessToken
    case gchatRefreshToken
    /// epoch ミリ秒の文字列
    case gchatTokenExpiresAt
    /// トークン発行時の client ID（変更検知用）
    case gchatClientId
}

/// シークレット永続化。アプリでは Keychain 実装、テストではインメモリ実装を使う。
public protocol SecretStore: Sendable {
    func secret(for key: SecretKey) throws -> String?
    func setSecret(_ value: String, for key: SecretKey) throws
    func removeSecret(for key: SecretKey) throws
}

public extension SecretStore {
    func removeSecrets(for keys: [SecretKey]) throws {
        for key in keys {
            try removeSecret(for: key)
        }
    }
}

public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var storage: [SecretKey: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func secret(for key: SecretKey) throws -> String? {
        lock.withLock { storage[key] }
    }

    public func setSecret(_ value: String, for key: SecretKey) throws {
        lock.withLock { storage[key] = value }
    }

    public func removeSecret(for key: SecretKey) throws {
        _ = lock.withLock { storage.removeValue(forKey: key) }
    }
}
