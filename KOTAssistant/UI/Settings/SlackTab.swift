import KOTCore
import KOTNotifications
import SwiftUI

/// Slack 連携（メッセージ通知＋ステータス更新）。変更は即時保存。
struct SlackTab: View {
    let model: AppModel

    @State private var form = FormState()
    @State private var loaded = false
    @State private var messageResult = ""
    @State private var messageIsError = false
    @State private var statusResult = ""
    @State private var statusIsError = false

    struct FormState: Equatable {
        var message = SlackMessageSettings()
        var status = SlackStatusSettings()
        var channels = ""
        var webhookURLs = ""
        var messageToken = ""
        var statusToken = ""
    }

    var body: some View {
        Form {
            Section {
                FeatureToggleRow(
                    title: "メッセージ通知",
                    description: "打刻時に Slack チャンネルへメッセージを投稿します。チャンネル・トークン・Webhook URL はスペース区切りで複数指定できます。",
                    isOn: $form.message.enabled
                )
                TextField("チャンネル", text: $form.channels, prompt: Text("#kintai #general"))
                Picker("投稿方法", selection: $form.message.apiType) {
                    Text("ユーザーとして投稿（OAuth トークン）").tag(SlackMessageSettings.APIType.asUser)
                    Text("Incoming Webhooks").tag(SlackMessageSettings.APIType.incomingWebhook)
                }
                if form.message.apiType == .asUser {
                    SecureField("OAuth トークン", text: $form.messageToken)
                } else {
                    TextField("Webhook URL（チャンネルと同順）", text: $form.webhookURLs)
                }
            }

            Section {
                MessageFields(
                    clockIn: $form.message.clockInMessage,
                    clockOut: $form.message.clockOutMessage,
                    breakStart: $form.message.breakStartMessage,
                    breakEnd: $form.message.breakEndMessage
                )
                HStack {
                    Button("テスト送信") { Task { await testMessage() } }
                    ResultText(text: messageResult, isError: messageIsError)
                }
            } header: {
                Text("メッセージ内容")
            } footer: {
                Text("空欄のアクションは通知されません。")
            }

            Section {
                FeatureToggleRow(
                    title: "ステータス更新",
                    description: "打刻に合わせて Slack のステータス絵文字とテキストを変更します。休憩終了時は出勤時のステータスに戻ります。",
                    isOn: $form.status.enabled
                )
                SecureField("OAuth トークン", text: $form.statusToken)
                LabeledContent("出勤") {
                    statusFields(emoji: $form.status.clockIn.emoji, text: $form.status.clockIn.text,
                                 emojiPrompt: ":office:", textPrompt: "仕事中")
                }
                LabeledContent("退勤") {
                    statusFields(emoji: $form.status.clockOut.emoji, text: $form.status.clockOut.text,
                                 emojiPrompt: ":house:", textPrompt: "退勤しました")
                }
                LabeledContent("休憩中") {
                    statusFields(emoji: $form.status.breakStart.emoji, text: $form.status.breakStart.text,
                                 emojiPrompt: ":coffee:", textPrompt: "休憩中")
                }
                HStack {
                    Button("テスト送信") { Task { await testStatus() } }
                    ResultText(text: statusResult, isError: statusIsError)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { load() }
        .onChange(of: form) { save() }
    }

    private func statusFields(
        emoji: Binding<String>, text: Binding<String>,
        emojiPrompt: String, textPrompt: String
    ) -> some View {
        HStack {
            TextField("絵文字", text: emoji, prompt: Text(emojiPrompt))
                .frame(width: 120)
            TextField("テキスト", text: text, prompt: Text(textPrompt))
        }
    }

    private func load() {
        let settings = model.settingsStore.load()
        form.message = settings.slackMessage
        form.status = settings.slackStatus
        form.channels = SpaceDelimited.toText(settings.slackMessage.channels)
        form.webhookURLs = SpaceDelimited.toText(settings.slackMessage.webhookURLs)
        form.messageToken = model.secret(.slackToken)
        form.statusToken = model.secret(.slackStatusToken)
        loaded = true
    }

    private func save() {
        guard loaded else { return }
        var settings = model.settingsStore.load()
        var message = form.message
        message.channels = SpaceDelimited.toList(form.channels)
        message.webhookURLs = SpaceDelimited.toList(form.webhookURLs)
        settings.slackMessage = message
        settings.slackStatus = form.status
        model.settingsStore.save(settings)
        model.setSecret(form.messageToken, for: .slackToken)
        model.setSecret(form.statusToken, for: .slackStatusToken)
    }

    private func testMessage() async {
        var current = form.message
        current.channels = SpaceDelimited.toList(form.channels)
        current.webhookURLs = SpaceDelimited.toList(form.webhookURLs)
        let text = current.clockInMessage.isEmpty ? "テスト" : current.clockInMessage
        let client = SlackMessageClient(transport: model.transport)
        let results = await client.post(text: text, settings: current, tokens: SpaceDelimited.toList(form.messageToken))
        if let failure = results.first(where: { !$0.success }) {
            messageResult = "失敗 (\(failure.destination)): \(failure.detail ?? "")"
            messageIsError = true
        } else if results.isEmpty {
            messageResult = "送信先がありません"
            messageIsError = true
        } else {
            messageResult = "送信しました"
            messageIsError = false
        }
    }

    private func testStatus() async {
        let status = SlackStatusSettings.Status(
            emoji: form.status.clockIn.emoji.isEmpty ? ":office:" : form.status.clockIn.emoji,
            text: form.status.clockIn.text.isEmpty ? "仕事中" : form.status.clockIn.text
        )
        let client = SlackStatusClient(transport: model.transport)
        let results = await client.setStatus(status, tokens: SpaceDelimited.toList(form.statusToken))
        if let failure = results.first(where: { !$0.success }) {
            statusResult = "失敗: \(failure.detail ?? "")"
            statusIsError = true
        } else if results.isEmpty {
            statusResult = "トークンが未設定です"
            statusIsError = true
        } else {
            statusResult = "ステータスを更新しました"
            statusIsError = false
        }
    }
}
