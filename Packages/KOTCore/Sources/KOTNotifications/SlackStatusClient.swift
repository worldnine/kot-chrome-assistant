import Foundation
import KOTCore

/// Slack ステータス更新（users.profile.set）
public struct SlackStatusClient: Sendable {
    public static let endpoint = URL(string: "https://slack.com/api/users.profile.set")!

    private let transport: HTTPTransport

    public init(transport: HTTPTransport) {
        self.transport = transport
    }

    /// 全ワークスペース（トークンごと）にステータスを設定する
    public func setStatus(_ status: SlackStatusSettings.Status, tokens: [String]) async -> [DeliveryResult] {
        var results: [DeliveryResult] = []
        for (index, token) in tokens.enumerated() {
            let destination = "workspace[\(index)]"
            let request = JSONRequest.post(
                Self.endpoint,
                json: [
                    "profile": [
                        "status_emoji": status.emoji,
                        "status_text": status.text,
                        "status_expiration": 0,
                    ]
                ],
                bearerToken: token
            )
            do {
                let response = try await transport.send(request)
                results.append(response.slackDeliveryResult(destination: destination))
            } catch {
                results.append(.failed(destination, detail: String(describing: error)))
            }
        }
        return results
    }
}
