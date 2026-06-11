import AppKit
import Foundation
import KOTCore
import KOTNotifications

/// ループバックリダイレクトによる Google の対話的認可。
/// 既定ブラウザで同意画面を開き、127.0.0.1 のワンショットサーバでコードを受け取る。
struct GoogleLoopbackAuthorizer: GoogleInteractiveAuthorizer {
    let oauth: GoogleOAuthService
    /// ユーザーがブラウザ側を放置した場合の待ち時間上限
    var timeout: Duration = .seconds(300)

    func authorize(clientID: String, clientSecret: String) async throws -> OAuthTokenResponse {
        let (server, port) = try await LoopbackRedirectServer.startPreferringFixedPort()
        let redirectURI = "http://127.0.0.1:\(port)"
        let pkce = PKCE()
        let url = GoogleOAuthService.authorizationURL(clientID: clientID, redirectURI: redirectURI, pkce: pkce)

        await MainActor.run {
            NSWorkspace.shared.open(url)
        }

        let code = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await server.waitForCode()
            }
            group.addTask { [timeout] in
                try await Task.sleep(for: timeout)
                throw CancellationError()
            }
            defer {
                group.cancelAll()
                server.stop()
            }
            guard let code = try await group.next() else { throw CancellationError() }
            return code
        }

        return try await oauth.completeAuthorization(
            code: code,
            codeVerifier: pkce.codeVerifier,
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: redirectURI
        )
    }
}
