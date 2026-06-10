import Crypto
import Foundation

/// OAuth2 PKCE (RFC 7636) の code verifier / challenge 生成
public struct PKCE: Sendable {
    public let codeVerifier: String
    public let codeChallenge: String
    public let codeChallengeMethod = "S256"

    public init() {
        var bytes = [UInt8](repeating: 0, count: 32)
        var generator = SystemRandomNumberGenerator()
        for i in bytes.indices {
            bytes[i] = UInt8.random(in: .min ... .max, using: &generator)
        }
        self.init(verifierBytes: bytes)
    }

    init(verifierBytes: [UInt8]) {
        self.codeVerifier = Data(verifierBytes).base64URLEncodedString()
        self.codeChallenge = Self.challenge(for: codeVerifier)
    }

    public static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

extension Data {
    /// base64url（パディングなし）
    public func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
