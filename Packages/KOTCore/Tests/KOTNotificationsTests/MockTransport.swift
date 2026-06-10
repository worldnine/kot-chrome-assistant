import Foundation
@testable import KOTNotifications

/// リクエストを記録し、ハンドラでレスポンスを返すテスト用トランスポート
final class MockTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [HTTPRequest] = []
    private let handler: @Sendable (HTTPRequest) async throws -> HTTPResponse

    init(handler: @escaping @Sendable (HTTPRequest) async throws -> HTTPResponse = { _ in
        HTTPResponse(statusCode: 200, body: Data("{}".utf8))
    }) {
        self.handler = handler
    }

    var requests: [HTTPRequest] {
        lock.withLock { recorded }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { recorded.append(request) }
        return try await handler(request)
    }
}

extension HTTPRequest {
    /// JSON ボディのデコード（テスト用）
    var jsonBody: [String: Any] {
        guard let body, let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
            return [:]
        }
        return json
    }

    /// application/x-www-form-urlencoded ボディのデコード（テスト用）
    var formBody: [String: String] {
        guard let body, let text = String(data: body, encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for pair in text.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            result[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
        }
        return result
    }

    var bearerToken: String? {
        headers["Authorization"]?.replacingOccurrences(of: "Bearer ", with: "")
    }
}

func tokenResponseJSON(accessToken: String, refreshToken: String? = nil, expiresIn: Int = 3600) -> Data {
    var json: [String: Any] = ["access_token": accessToken, "expires_in": expiresIn]
    if let refreshToken {
        json["refresh_token"] = refreshToken
    }
    return try! JSONSerialization.data(withJSONObject: json)
}
