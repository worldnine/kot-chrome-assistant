import Foundation
import KOTCore

/// 打刻アクションを有効な全連携へ並行配信する。
/// fire-and-forget（失敗はログのみ、呼び元へ throw しない）— 原拡張と同じ。
public actor NotificationDispatcher {
    public typealias Logger = @Sendable (_ category: String, _ message: String) -> Void

    private let slackMessage: SlackMessageClient
    private let slackStatus: SlackStatusClient
    private let googleChatWebhook: GoogleChatWebhookClient
    private let googleChatUser: GoogleChatUserClient
    private let secrets: SecretStore
    private let log: Logger

    public init(
        transport: HTTPTransport,
        oauth: GoogleOAuthService,
        secrets: SecretStore,
        log: @escaping Logger = { category, message in print("[\(category)] \(message)") }
    ) {
        self.slackMessage = SlackMessageClient(transport: transport)
        self.slackStatus = SlackStatusClient(transport: transport)
        self.googleChatWebhook = GoogleChatWebhookClient(transport: transport)
        self.googleChatUser = GoogleChatUserClient(transport: transport, oauth: oauth)
        self.secrets = secrets
        self.log = log
    }

    public func dispatch(_ action: PunchAction, settings: AppSettings) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.dispatchSlackMessage(action, settings: settings.slackMessage) }
            group.addTask { await self.dispatchSlackStatus(action, settings: settings.slackStatus) }
            group.addTask { await self.dispatchGoogleChatWebhook(action, settings: settings.googleChatWebhook) }
            group.addTask { await self.dispatchGoogleChatUser(action, settings: settings.googleChatUser) }
        }
    }

    private func dispatchSlackMessage(_ action: PunchAction, settings: SlackMessageSettings) async {
        let message = settings.message(for: action)
        guard settings.enabled, !message.isEmpty else { return }
        let tokens = secretList(.slackToken)
        let results = await slackMessage.post(text: message, settings: settings, tokens: tokens)
        report(results, category: "SlackMessage")
    }

    private func dispatchSlackStatus(_ action: PunchAction, settings: SlackStatusSettings) async {
        guard settings.enabled else { return }
        let tokens = secretList(.slackStatusToken)
        let results = await slackStatus.setStatus(settings.status(for: action), tokens: tokens)
        report(results, category: "SlackStatus")
    }

    private func dispatchGoogleChatWebhook(_ action: PunchAction, settings: GoogleChatWebhookSettings) async {
        let message = settings.message(for: action)
        guard settings.enabled, !message.isEmpty else { return }
        let results = await googleChatWebhook.post(text: message, webhookURLs: settings.webhookURLs)
        report(results, category: "GoogleChatWebhook")
    }

    private func dispatchGoogleChatUser(_ action: PunchAction, settings: GoogleChatUserSettings) async {
        let message = settings.message(for: action)
        let clientSecret = (try? secrets.secret(for: .googleChatOAuthClientSecret)) ?? nil
        guard settings.enabled, !message.isEmpty,
              !settings.oauthClientID.isEmpty,
              let clientSecret, !clientSecret.isEmpty,
              !settings.spaces.isEmpty else { return }
        let results = await googleChatUser.postBatch(
            text: message,
            spaces: settings.spaces,
            clientID: settings.oauthClientID,
            clientSecret: clientSecret
        )
        report(results, category: "GoogleChatUser")
    }

    private func secretList(_ key: SecretKey) -> [String] {
        ((try? secrets.secret(for: key)) ?? nil ?? "")
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func report(_ results: [DeliveryResult], category: String) {
        for result in results where !result.success {
            log(category, "\(result.destination): \(result.detail ?? "送信に失敗しました")")
        }
    }
}
