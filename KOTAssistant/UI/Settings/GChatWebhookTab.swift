import KOTCore
import KOTNotifications
import SwiftUI

struct GChatWebhookTab: View {
    let model: AppModel

    @State private var settings = GoogleChatWebhookSettings()
    @State private var webhookURLs = ""
    @State private var result = ""
    @State private var isError = false

    var body: some View {
        Form {
            Section {
                Toggle("Google Chat Webhook 通知を有効にする", isOn: $settings.enabled)
                TextField("Webhook URL（スペース区切りで複数可）", text: $webhookURLs)
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
        settings = model.settingsStore.load().googleChatWebhook
        webhookURLs = SpaceDelimited.toText(settings.webhookURLs)
    }

    private func save() {
        var all = model.settingsStore.load()
        settings.webhookURLs = SpaceDelimited.toList(webhookURLs)
        all.googleChatWebhook = settings
        model.settingsStore.save(all)
        result = "保存しました"
        isError = false
    }

    private func test() async {
        let text = settings.clockInMessage.isEmpty ? "テスト" : settings.clockInMessage
        let client = GoogleChatWebhookClient(transport: model.transport)
        let results = await client.post(text: text, webhookURLs: SpaceDelimited.toList(webhookURLs))
        if let failure = results.first(where: { !$0.success }) {
            result = "失敗: \(failure.detail ?? "")"
            isError = true
        } else if results.isEmpty {
            result = "Webhook URL が未設定です"
            isError = true
        } else {
            result = "送信しました"
            isError = false
        }
    }
}
