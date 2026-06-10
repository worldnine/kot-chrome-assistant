import Foundation
import KOTCore

/// Slack メッセージ投稿（chat.postMessage / Incoming Webhook）
public struct SlackMessageClient: Sendable {
    public static let postMessageEndpoint = URL(string: "https://slack.com/api/chat.postMessage")!

    private let transport: HTTPTransport

    public init(transport: HTTPTransport) {
        self.transport = transport
    }

    public func post(text: String, settings: SlackMessageSettings, tokens: [String]) async -> [DeliveryResult] {
        switch settings.apiType {
        case .asUser:
            return await postAsUser(text: text, channels: settings.channels, tokens: tokens)
        case .incomingWebhook:
            return await postViaWebhooks(text: text, channels: settings.channels, webhookURLs: settings.webhookURLs)
        }
    }

    /// chat.postMessage。トークンが 1 個なら全チャンネル共通、複数ならチャンネルと同順で対応
    /// （原拡張のローテーション規則そのまま）。
    public func postAsUser(text: String, channels: [String], tokens: [String]) async -> [DeliveryResult] {
        var results: [DeliveryResult] = []
        for (index, channel) in channels.enumerated() {
            let token: String
            if tokens.count > 1 {
                guard index < tokens.count else {
                    results.append(.failed(channel, detail: "チャンネルに対応するトークンがありません"))
                    continue
                }
                token = tokens[index]
            } else if let first = tokens.first {
                token = first
            } else {
                results.append(.failed(channel, detail: "Slack トークンが未設定です"))
                continue
            }

            let request = JSONRequest.post(
                Self.postMessageEndpoint,
                json: ["channel": channel, "text": text, "as_user": true],
                bearerToken: token
            )
            results.append(await send(request, destination: channel, slackAPI: true))
        }
        return results
    }

    /// Incoming Webhook。webhookURLs[i] と channels[i] が 1:1 で対応する。
    public func postViaWebhooks(text: String, channels: [String], webhookURLs: [String]) async -> [DeliveryResult] {
        var results: [DeliveryResult] = []
        for (index, channel) in channels.enumerated() {
            guard index < webhookURLs.count, let url = URL(string: webhookURLs[index]) else {
                results.append(.failed(channel, detail: "チャンネルに対応する Webhook URL がありません"))
                continue
            }
            let request = JSONRequest.post(url, json: ["channel": channel, "text": text])
            results.append(await send(request, destination: channel, slackAPI: false))
        }
        return results
    }

    private func send(_ request: HTTPRequest, destination: String, slackAPI: Bool) async -> DeliveryResult {
        do {
            let response = try await transport.send(request)
            return slackAPI
                ? response.slackDeliveryResult(destination: destination)
                : response.deliveryResult(destination: destination)
        } catch {
            return .failed(destination, detail: String(describing: error))
        }
    }
}
