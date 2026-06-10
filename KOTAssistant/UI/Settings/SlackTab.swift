import KOTCore
import KOTNotifications
import SwiftUI

struct SlackTab: View {
    let model: AppModel

    @State private var settings = SlackMessageSettings()
    @State private var channels = ""
    @State private var webhookURLs = ""
    @State private var token = ""
    @State private var result = ""
    @State private var isError = false

    var body: some View {
        Form {
            Section {
                Toggle("Slack メッセージ通知を有効にする", isOn: $settings.enabled)
                TextField("チャンネル（スペース区切りで複数可）", text: $channels, prompt: Text("#kintai #general"))
                Picker("投稿方法", selection: $settings.apiType) {
                    Text("ユーザーとして投稿（OAuth トークン）").tag(SlackMessageSettings.APIType.asUser)
                    Text("Incoming Webhooks").tag(SlackMessageSettings.APIType.incomingWebhook)
                }
                if settings.apiType == .asUser {
                    SecureField("OAuth トークン（スペース区切りで複数可）", text: $token)
                } else {
                    TextField("Webhook URL（スペース区切り・チャンネルと同順）", text: $webhookURLs)
                }
            }

            Section("メッセージ（空欄のアクションは通知されません）") {
                TextField("出勤", text: $settings.clockInMessage)
                TextField("退勤", text: $settings.clockOutMessage)
                TextField("休憩開始", text: $settings.breakStartMessage)
                TextField("休憩終了", text: $settings.breakEndMessage)
            }

            Section {
                HStack {
                    Button("保存") { save() }
                    Button("テスト送信") { Task { await test() } }
                    ResultText(text: result, isError: isError)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { load() }
    }

    private func load() {
        settings = model.settingsStore.load().slackMessage
        channels = SpaceDelimited.toText(settings.channels)
        webhookURLs = SpaceDelimited.toText(settings.webhookURLs)
        token = model.secret(.slackToken)
    }

    private func currentSettings() -> SlackMessageSettings {
        var current = settings
        current.channels = SpaceDelimited.toList(channels)
        current.webhookURLs = SpaceDelimited.toList(webhookURLs)
        return current
    }

    private func save() {
        var all = model.settingsStore.load()
        all.slackMessage = currentSettings()
        model.settingsStore.save(all)
        model.setSecret(token, for: .slackToken)
        result = "保存しました"
        isError = false
    }

    private func test() async {
        let current = currentSettings()
        let text = current.clockInMessage.isEmpty ? "テスト" : current.clockInMessage
        let client = SlackMessageClient(transport: model.transport)
        let results = await client.post(text: text, settings: current, tokens: SpaceDelimited.toList(token))
        showResults(results)
    }

    private func showResults(_ results: [DeliveryResult]) {
        if let failure = results.first(where: { !$0.success }) {
            result = "失敗 (\(failure.destination)): \(failure.detail ?? "")"
            isError = true
        } else if results.isEmpty {
            result = "送信先がありません"
            isError = true
        } else {
            result = "送信しました"
            isError = false
        }
    }
}
