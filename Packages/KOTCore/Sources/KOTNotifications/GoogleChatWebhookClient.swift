import Foundation
import KOTCore

/// Google Chat Incoming Webhook 投稿
public struct GoogleChatWebhookClient: Sendable {
    private let transport: HTTPTransport

    public init(transport: HTTPTransport) {
        self.transport = transport
    }

    public func post(text: String, webhookURLs: [String]) async -> [DeliveryResult] {
        var results: [DeliveryResult] = []
        for urlString in webhookURLs {
            guard let url = URL(string: urlString) else {
                results.append(.failed(urlString, detail: "不正な URL です"))
                continue
            }
            let request = JSONRequest.post(url, json: ["text": text])
            do {
                let response = try await transport.send(request)
                results.append(response.deliveryResult(destination: urlString))
            } catch {
                results.append(.failed(urlString, detail: String(describing: error)))
            }
        }
        return results
    }
}
