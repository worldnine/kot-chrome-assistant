import Foundation

/// 通知 1 件の送信結果（fire-and-forget だがログ・テスト送信 UI 用に返す）
public struct DeliveryResult: Equatable, Sendable {
    /// チャンネル名 / Webhook URL / スペース ID など
    public let destination: String
    public let success: Bool
    public let detail: String?
    /// HTTP ステータス（リトライ判定用）
    public let httpStatus: Int?

    public init(destination: String, success: Bool, detail: String? = nil, httpStatus: Int? = nil) {
        self.destination = destination
        self.success = success
        self.detail = detail
        self.httpStatus = httpStatus
    }

    public static func ok(_ destination: String, httpStatus: Int? = nil) -> DeliveryResult {
        DeliveryResult(destination: destination, success: true, httpStatus: httpStatus)
    }

    public static func failed(_ destination: String, detail: String, httpStatus: Int? = nil) -> DeliveryResult {
        DeliveryResult(destination: destination, success: false, detail: detail, httpStatus: httpStatus)
    }
}

extension HTTPResponse {
    /// Slack API は HTTP 200 でも `{"ok": false}` を返すことがある
    func slackDeliveryResult(destination: String) -> DeliveryResult {
        guard isSuccess else {
            return .failed(destination, detail: "HTTP \(statusCode): \(bodyText)", httpStatus: statusCode)
        }
        if let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let ok = json["ok"] as? Bool, !ok {
            return .failed(destination, detail: bodyText, httpStatus: statusCode)
        }
        return .ok(destination, httpStatus: statusCode)
    }

    func deliveryResult(destination: String) -> DeliveryResult {
        guard isSuccess else {
            return .failed(destination, detail: "HTTP \(statusCode): \(bodyText)", httpStatus: statusCode)
        }
        return .ok(destination, httpStatus: statusCode)
    }
}
