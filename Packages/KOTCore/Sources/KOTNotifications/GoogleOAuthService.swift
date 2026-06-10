import Foundation
import KOTCore

/// Google の token エンドポイントのレスポンス
public struct OAuthTokenResponse: Decodable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }

    public init(accessToken: String, refreshToken: String?, expiresIn: Int) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }
}

public enum GoogleOAuthError: Error, Equatable {
    /// リフレッシュトークンがなく、対話的認可も許可されていない
    case notConnected
    case tokenRequestFailed(String)
    case authorizationFailed(String)
}

/// 対話的認可（ブラウザ起動＋リダイレクト受け取り）。アプリ層が実装する。
public protocol GoogleInteractiveAuthorizer: Sendable {
    func authorize(clientID: String, clientSecret: String) async throws -> OAuthTokenResponse
}

/// Google Chat 用 OAuth2 トークン管理。
/// 原拡張 background.js の acquireToken / refreshAccessToken / saveTokenData と同じ挙動:
/// - 期限は発行時刻 + (expires_in - 300) 秒（5 分バッファ）
/// - client ID が変わっていたら保存済みトークンを破棄
/// - リフレッシュは single-flight（並行呼び出しは同じ Task を待つ）
public actor GoogleOAuthService {
    public static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!
    public static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    public static let revokeEndpoint = URL(string: "https://accounts.google.com/o/oauth2/revoke")!
    public static let scope = "https://www.googleapis.com/auth/chat.messages.create"

    private let transport: HTTPTransport
    private let secrets: SecretStore
    private let now: @Sendable () -> Date
    private var authorizer: GoogleInteractiveAuthorizer?
    private var refreshTask: Task<String, Error>?

    public init(
        transport: HTTPTransport,
        secrets: SecretStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.secrets = secrets
        self.now = now
    }

    public func setAuthorizer(_ authorizer: GoogleInteractiveAuthorizer?) {
        self.authorizer = authorizer
    }

    // MARK: - トークン取得

    /// 有効なアクセストークンを返す。必要ならリフレッシュ、
    /// `allowInteractive` が true ならブラウザ認可までフォールバックする。
    public func accessToken(clientID: String, clientSecret: String, allowInteractive: Bool = false) async throws -> String {
        invalidateIfClientChanged(clientID: clientID)

        if let token = try? secrets.secret(for: .gchatAccessToken),
           let expiresAtString = try? secrets.secret(for: .gchatTokenExpiresAt),
           let expiresAt = Double(expiresAtString),
           now().timeIntervalSince1970 * 1000 < expiresAt {
            return token
        }

        if let refreshToken = try? secrets.secret(for: .gchatRefreshToken), !refreshToken.isEmpty {
            do {
                return try await singleFlightRefresh(clientID: clientID, clientSecret: clientSecret, refreshToken: refreshToken)
            } catch {
                // リフレッシュ失敗 → トークン破棄して対話的認可へフォールバック（原拡張と同じ）
                clearTokens()
            }
        }

        guard allowInteractive, let authorizer else {
            throw GoogleOAuthError.notConnected
        }
        let response = try await authorizer.authorize(clientID: clientID, clientSecret: clientSecret)
        store(response, clientID: clientID)
        return response.accessToken
    }

    /// access token のみ無効化（refresh token は残す）。401 復旧用。
    public func invalidateAccessToken() {
        try? secrets.removeSecret(for: .gchatAccessToken)
        try? secrets.removeSecret(for: .gchatTokenExpiresAt)
    }

    /// 接続状態の確認。refresh token が現在の資格情報で使えるか実際に試す（原拡張と同じ）。
    public func checkConnection(clientID: String, clientSecret: String) async -> Bool {
        invalidateIfClientChanged(clientID: clientID)
        guard let refreshToken = try? secrets.secret(for: .gchatRefreshToken), !refreshToken.isEmpty else {
            return false
        }
        do {
            _ = try await singleFlightRefresh(clientID: clientID, clientSecret: clientSecret, refreshToken: refreshToken)
            return true
        } catch {
            clearTokens()
            return false
        }
    }

    /// 切断: トークンを revoke してローカルから破棄する。
    public func disconnect() async {
        let accessToken = try? secrets.secret(for: .gchatAccessToken)
        clearTokens()
        if let accessToken, !accessToken.isEmpty {
            var components = URLComponents(url: Self.revokeEndpoint, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "token", value: accessToken)]
            _ = try? await transport.send(HTTPRequest(method: "GET", url: components.url!))
        }
    }

    // MARK: - 認可フロー部品（アプリ層の authorizer 実装が使う）

    public nonisolated static func authorizationURL(clientID: String, redirectURI: String, pkce: PKCE) -> URL {
        var components = URLComponents(url: authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: pkce.codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: pkce.codeChallengeMethod),
        ]
        return components.url!
    }

    /// 認可コードをトークンに交換して保存する。
    @discardableResult
    public func completeAuthorization(
        code: String,
        codeVerifier: String,
        clientID: String,
        clientSecret: String,
        redirectURI: String
    ) async throws -> OAuthTokenResponse {
        let response = try await requestToken(form: [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ])
        store(response, clientID: clientID)
        return response
    }

    // MARK: - 内部実装

    private func singleFlightRefresh(clientID: String, clientSecret: String, refreshToken: String) async throws -> String {
        if let task = refreshTask {
            return try await task.value
        }
        let task = Task<String, Error> {
            let response = try await self.requestToken(form: [
                "client_id": clientID,
                "client_secret": clientSecret,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token",
            ])
            // refresh_token がレスポンスに含まれない場合は既存のものを維持
            let merged = OAuthTokenResponse(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? refreshToken,
                expiresIn: response.expiresIn
            )
            self.store(merged, clientID: clientID)
            return merged.accessToken
        }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func requestToken(form: [String: String]) async throws -> OAuthTokenResponse {
        let body = form
            .map { key, value in
                let escaped = value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? value
                return "\(key)=\(escaped)"
            }
            .joined(separator: "&")
        let request = HTTPRequest(
            url: Self.tokenEndpoint,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            body: Data(body.utf8)
        )
        let response: HTTPResponse
        do {
            response = try await transport.send(request)
        } catch {
            throw GoogleOAuthError.tokenRequestFailed(String(describing: error))
        }
        guard response.isSuccess else {
            throw GoogleOAuthError.tokenRequestFailed("HTTP \(response.statusCode): \(response.bodyText)")
        }
        do {
            return try JSONDecoder().decode(OAuthTokenResponse.self, from: response.body)
        } catch {
            throw GoogleOAuthError.tokenRequestFailed("レスポンスのパースに失敗: \(response.bodyText)")
        }
    }

    private func store(_ response: OAuthTokenResponse, clientID: String) {
        let expiresAt = (now().timeIntervalSince1970 + Double(response.expiresIn - 300)) * 1000
        try? secrets.setSecret(response.accessToken, for: .gchatAccessToken)
        try? secrets.setSecret(String(expiresAt), for: .gchatTokenExpiresAt)
        try? secrets.setSecret(clientID, for: .gchatClientId)
        if let refreshToken = response.refreshToken {
            try? secrets.setSecret(refreshToken, for: .gchatRefreshToken)
        }
    }

    private func invalidateIfClientChanged(clientID: String) {
        if let stored = try? secrets.secret(for: .gchatClientId), !stored.isEmpty, stored != clientID {
            clearTokens()
        }
    }

    private func clearTokens() {
        try? secrets.removeSecrets(for: [.gchatAccessToken, .gchatTokenExpiresAt, .gchatRefreshToken, .gchatClientId])
    }
}
