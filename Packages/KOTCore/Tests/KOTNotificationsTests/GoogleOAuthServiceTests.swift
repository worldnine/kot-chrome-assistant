import Foundation
import Testing
import KOTCore
@testable import KOTNotifications

@Suite struct GoogleOAuthServiceTests {
    private let clientID = "cid"
    private let clientSecret = "sec"

    private func makeSecrets(
        accessToken: String? = nil,
        expiresAt: Double? = nil,
        refreshToken: String? = nil,
        storedClientID: String? = nil
    ) -> InMemorySecretStore {
        let secrets = InMemorySecretStore()
        if let accessToken { try! secrets.setSecret(accessToken, for: .gchatAccessToken) }
        if let expiresAt { try! secrets.setSecret(String(expiresAt), for: .gchatTokenExpiresAt) }
        if let refreshToken { try! secrets.setSecret(refreshToken, for: .gchatRefreshToken) }
        if let storedClientID { try! secrets.setSecret(storedClientID, for: .gchatClientId) }
        return secrets
    }

    @Test func returnsStoredTokenWhileValid() async throws {
        let now = Date()
        let secrets = makeSecrets(
            accessToken: "stored",
            expiresAt: (now.timeIntervalSince1970 + 60) * 1000,
            storedClientID: clientID
        )
        let transport = MockTransport()
        let service = GoogleOAuthService(transport: transport, secrets: secrets, now: { now })

        let token = try await service.accessToken(clientID: clientID, clientSecret: clientSecret)
        #expect(token == "stored")
        #expect(transport.requests.isEmpty)
    }

    @Test func refreshesExpiredToken() async throws {
        let now = Date()
        let secrets = makeSecrets(
            accessToken: "expired",
            expiresAt: (now.timeIntervalSince1970 - 1) * 1000,
            refreshToken: "refresh1",
            storedClientID: clientID
        )
        let transport = MockTransport { _ in
            HTTPResponse(statusCode: 200, body: tokenResponseJSON(accessToken: "fresh", expiresIn: 3600))
        }
        let service = GoogleOAuthService(transport: transport, secrets: secrets, now: { now })

        let token = try await service.accessToken(clientID: clientID, clientSecret: clientSecret)
        #expect(token == "fresh")

        let request = transport.requests[0]
        #expect(request.url == GoogleOAuthService.tokenEndpoint)
        #expect(request.formBody["grant_type"] == "refresh_token")
        #expect(request.formBody["refresh_token"] == "refresh1")
        #expect(request.formBody["client_id"] == clientID)
        #expect(request.formBody["client_secret"] == clientSecret)

        // レスポンスに refresh_token がなければ既存を維持
        #expect(try secrets.secret(for: .gchatRefreshToken) == "refresh1")
        // 期限は 5 分バッファ付きで保存される
        let expiresAt = Double(try secrets.secret(for: .gchatTokenExpiresAt)!)!
        let expected = (now.timeIntervalSince1970 + Double(3600 - 300)) * 1000
        #expect(abs(expiresAt - expected) < 1)
    }

    @Test func refreshIsSingleFlight() async throws {
        let now = Date()
        let secrets = makeSecrets(refreshToken: "refresh1", storedClientID: clientID)
        let transport = MockTransport { _ in
            try await Task.sleep(nanoseconds: 50_000_000)
            return HTTPResponse(statusCode: 200, body: tokenResponseJSON(accessToken: "fresh"))
        }
        let service = GoogleOAuthService(transport: transport, secrets: secrets, now: { now })

        async let first = service.accessToken(clientID: clientID, clientSecret: clientSecret)
        async let second = service.accessToken(clientID: clientID, clientSecret: clientSecret)
        let tokens = try await (first, second)

        #expect(tokens == ("fresh", "fresh"))
        #expect(transport.requests.count == 1)
    }

    @Test func clientIDChangeWipesStoredTokens() async {
        let secrets = makeSecrets(
            accessToken: "stored",
            expiresAt: (Date().timeIntervalSince1970 + 600) * 1000,
            refreshToken: "refresh1",
            storedClientID: "other-client"
        )
        let service = GoogleOAuthService(transport: MockTransport(), secrets: secrets)

        await #expect(throws: GoogleOAuthError.notConnected) {
            try await service.accessToken(clientID: clientID, clientSecret: clientSecret)
        }
        #expect(try! secrets.secret(for: .gchatRefreshToken) == nil)
        #expect(try! secrets.secret(for: .gchatAccessToken) == nil)
    }

    @Test func notConnectedWithoutRefreshTokenOrAuthorizer() async {
        let service = GoogleOAuthService(transport: MockTransport(), secrets: InMemorySecretStore())
        await #expect(throws: GoogleOAuthError.notConnected) {
            try await service.accessToken(clientID: clientID, clientSecret: clientSecret)
        }
    }

    @Test func completeAuthorizationExchangesCodeAndStores() async throws {
        let now = Date()
        let secrets = InMemorySecretStore()
        let transport = MockTransport { _ in
            HTTPResponse(statusCode: 200, body: tokenResponseJSON(accessToken: "at", refreshToken: "rt", expiresIn: 3600))
        }
        let service = GoogleOAuthService(transport: transport, secrets: secrets, now: { now })

        let response = try await service.completeAuthorization(
            code: "authcode",
            codeVerifier: "verifier",
            clientID: clientID,
            clientSecret: clientSecret,
            redirectURI: "http://127.0.0.1:8000"
        )
        #expect(response.accessToken == "at")

        let form = transport.requests[0].formBody
        #expect(form["grant_type"] == "authorization_code")
        #expect(form["code"] == "authcode")
        #expect(form["code_verifier"] == "verifier")
        #expect(form["redirect_uri"] == "http://127.0.0.1:8000")

        #expect(try secrets.secret(for: .gchatAccessToken) == "at")
        #expect(try secrets.secret(for: .gchatRefreshToken) == "rt")
        #expect(try secrets.secret(for: .gchatClientId) == clientID)
    }

    @Test func disconnectRevokesAndWipes() async throws {
        let secrets = makeSecrets(accessToken: "at", refreshToken: "rt", storedClientID: clientID)
        let transport = MockTransport()
        let service = GoogleOAuthService(transport: transport, secrets: secrets)

        await service.disconnect()

        #expect(try secrets.secret(for: .gchatAccessToken) == nil)
        #expect(try secrets.secret(for: .gchatRefreshToken) == nil)
        let revoke = transport.requests[0]
        #expect(revoke.method == "GET")
        #expect(revoke.url.absoluteString.hasPrefix("https://accounts.google.com/o/oauth2/revoke?token=at"))
    }

    @Test func authorizationURLContainsPKCEAndOfflineAccess() {
        let pkce = PKCE()
        let url = GoogleOAuthService.authorizationURL(clientID: clientID, redirectURI: "http://127.0.0.1:9999", pkce: pkce)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        #expect(value("client_id") == clientID)
        #expect(value("response_type") == "code")
        #expect(value("scope") == GoogleOAuthService.scope)
        #expect(value("access_type") == "offline")
        #expect(value("prompt") == "consent")
        #expect(value("code_challenge") == pkce.codeChallenge)
        #expect(value("code_challenge_method") == "S256")
    }
}
