import Foundation
import Testing
import KOTCore
@testable import KOTNotifications

@Suite struct GoogleChatUserClientTests {
    private let clientID = "cid"
    private let clientSecret = "sec"

    private func validSecrets() -> InMemorySecretStore {
        let secrets = InMemorySecretStore()
        try! secrets.setSecret("valid-token", for: .gchatAccessToken)
        try! secrets.setSecret(String((Date().timeIntervalSince1970 + 600) * 1000), for: .gchatTokenExpiresAt)
        try! secrets.setSecret("rt", for: .gchatRefreshToken)
        try! secrets.setSecret(clientID, for: .gchatClientId)
        return secrets
    }

    @Test func postsToAllSpacesWithNormalizedIDs() async {
        let transport = MockTransport()
        let oauth = GoogleOAuthService(transport: transport, secrets: validSecrets())
        let client = GoogleChatUserClient(transport: transport, oauth: oauth)

        let results = await client.postBatch(
            text: "出社しました。",
            spaces: ["spaces/AAA", "https://chat.google.com/room/BBB", "CCC"],
            clientID: clientID,
            clientSecret: clientSecret
        )

        #expect(results.map(\.success) == Array(repeating: true, count: results.count))
        let urls = transport.requests.map(\.url.absoluteString)
        #expect(urls == [
            "https://chat.googleapis.com/v1/spaces/AAA/messages",
            "https://chat.googleapis.com/v1/spaces/BBB/messages",
            "https://chat.googleapis.com/v1/spaces/CCC/messages",
        ])
        #expect(transport.requests.allSatisfy { $0.bearerToken == "valid-token" })
        #expect(transport.requests[0].jsonBody["text"] as? String == "出社しました。")
    }

    @Test func retriesOnceOn401WithRefreshedToken() async {
        // 1 回目の投稿は 401 → リフレッシュ → 再送で成功（原拡張の復旧パス）
        let counter = RequestCounter()
        let transport = MockTransport { request in
            if request.url == GoogleOAuthService.tokenEndpoint {
                return HTTPResponse(statusCode: 200, body: tokenResponseJSON(accessToken: "refreshed"))
            }
            let isFirstPost = await counter.next() == 0
            if isFirstPost {
                return HTTPResponse(statusCode: 401, body: Data("unauthorized".utf8))
            }
            return HTTPResponse(statusCode: 200, body: Data("{}".utf8))
        }
        let oauth = GoogleOAuthService(transport: transport, secrets: validSecrets())
        let client = GoogleChatUserClient(transport: transport, oauth: oauth)

        let results = await client.postBatch(text: "x", spaces: ["AAA"], clientID: clientID, clientSecret: clientSecret)

        #expect(results == [.ok("AAA", httpStatus: 200)])
        let postRequests = transport.requests.filter { $0.url != GoogleOAuthService.tokenEndpoint }
        #expect(postRequests.count == 2)
        #expect(postRequests[0].bearerToken == "valid-token")
        #expect(postRequests[1].bearerToken == "refreshed")
    }

    @Test func non401FailureIsNotRetried() async {
        let transport = MockTransport { request in
            if request.url == GoogleOAuthService.tokenEndpoint {
                return HTTPResponse(statusCode: 200, body: tokenResponseJSON(accessToken: "t"))
            }
            return HTTPResponse(statusCode: 403, body: Data("forbidden".utf8))
        }
        let oauth = GoogleOAuthService(transport: transport, secrets: validSecrets())
        let client = GoogleChatUserClient(transport: transport, oauth: oauth)

        let results = await client.postBatch(text: "x", spaces: ["AAA"], clientID: clientID, clientSecret: clientSecret)

        #expect(!results[0].success)
        #expect(results[0].httpStatus == 403)
        let postRequests = transport.requests.filter { $0.url != GoogleOAuthService.tokenEndpoint }
        #expect(postRequests.count == 1)
    }

    @Test func notConnectedFailsAllSpaces() async {
        let transport = MockTransport()
        let oauth = GoogleOAuthService(transport: transport, secrets: InMemorySecretStore())
        let client = GoogleChatUserClient(transport: transport, oauth: oauth)

        let results = await client.postBatch(text: "x", spaces: ["AAA", "BBB"], clientID: clientID, clientSecret: clientSecret)

        #expect(results.count == 2)
        #expect(results.map(\.success) == Array(repeating: false, count: results.count))
        #expect(transport.requests.isEmpty)
    }
}

private actor RequestCounter {
    private var count = 0

    func next() -> Int {
        defer { count += 1 }
        return count
    }
}
