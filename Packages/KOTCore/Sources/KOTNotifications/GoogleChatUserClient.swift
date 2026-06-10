import Foundation
import KOTCore

/// Google Chat ユーザー認証投稿（spaces.messages.create）。
/// 複数スペースへの一括投稿、401 時はアクセストークンを無効化して 1 回だけ再送（原拡張と同じ）。
public struct GoogleChatUserClient: Sendable {
    private let transport: HTTPTransport
    private let oauth: GoogleOAuthService

    public init(transport: HTTPTransport, oauth: GoogleOAuthService) {
        self.transport = transport
        self.oauth = oauth
    }

    public func postBatch(
        text: String,
        spaces: [String],
        clientID: String,
        clientSecret: String,
        allowInteractive: Bool = false
    ) async -> [DeliveryResult] {
        let token: String
        do {
            token = try await oauth.accessToken(clientID: clientID, clientSecret: clientSecret, allowInteractive: allowInteractive)
        } catch {
            return spaces.map { .failed($0, detail: "認証に失敗しました: \(error)") }
        }

        var results = await postToAllSpaces(token: token, spaces: spaces, text: text)

        let failedWith401 = results.filter { $0.httpStatus == 401 }
        if !failedWith401.isEmpty {
            await oauth.invalidateAccessToken()
            do {
                let newToken = try await oauth.accessToken(clientID: clientID, clientSecret: clientSecret, allowInteractive: false)
                let retrySpaces = failedWith401.map(\.destination)
                let retryResults = await postToAllSpaces(token: newToken, spaces: retrySpaces, text: text)
                results = results.map { result in
                    retryResults.first { $0.destination == result.destination } ?? result
                }
            } catch {
                // 再認証失敗時は元の結果を返す（原拡張と同じ）
            }
        }
        return results
    }

    private func postToAllSpaces(token: String, spaces: [String], text: String) async -> [DeliveryResult] {
        var results: [DeliveryResult] = []
        for space in spaces {
            let normalized = SpaceID.normalize(space)
            guard let url = URL(string: "https://chat.googleapis.com/v1/spaces/\(normalized)/messages") else {
                results.append(.failed(space, detail: "不正なスペース ID です"))
                continue
            }
            let request = JSONRequest.post(url, json: ["text": text], bearerToken: token)
            do {
                let response = try await transport.send(request)
                if response.isSuccess {
                    results.append(.ok(space, httpStatus: response.statusCode))
                } else {
                    results.append(.failed(space, detail: "HTTP \(response.statusCode): \(response.bodyText)", httpStatus: response.statusCode))
                }
            } catch {
                results.append(.failed(space, detail: String(describing: error)))
            }
        }
        return results
    }
}
