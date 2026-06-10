import KOTCore
import KOTNotifications
import SwiftUI

struct SlackStatusTab: View {
    let model: AppModel

    @State private var settings = SlackStatusSettings()
    @State private var token = ""
    @State private var result = ""
    @State private var isError = false

    var body: some View {
        Form {
            Section {
                Toggle("Slack ステータス更新を有効にする", isOn: $settings.enabled)
                SecureField("OAuth トークン（スペース区切りで複数可）", text: $token)
            }

            Section("出勤時（休憩終了時もこのステータスに戻ります）") {
                TextField("絵文字", text: $settings.clockIn.emoji, prompt: Text(":office:"))
                TextField("テキスト", text: $settings.clockIn.text, prompt: Text("仕事中"))
            }

            Section("退勤時") {
                TextField("絵文字", text: $settings.clockOut.emoji, prompt: Text(":house:"))
                TextField("テキスト", text: $settings.clockOut.text, prompt: Text("退勤しました"))
            }

            Section("休憩中") {
                TextField("絵文字", text: $settings.breakStart.emoji, prompt: Text(":coffee:"))
                TextField("テキスト", text: $settings.breakStart.text, prompt: Text("休憩中"))
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
        settings = model.settingsStore.load().slackStatus
        token = model.secret(.slackStatusToken)
    }

    private func save() {
        var all = model.settingsStore.load()
        all.slackStatus = settings
        model.settingsStore.save(all)
        model.setSecret(token, for: .slackStatusToken)
        result = "保存しました"
        isError = false
    }

    private func test() async {
        // 原拡張のテストと同じく、出勤ステータス（未入力なら :office: 仕事中）を設定する
        let status = SlackStatusSettings.Status(
            emoji: settings.clockIn.emoji.isEmpty ? ":office:" : settings.clockIn.emoji,
            text: settings.clockIn.text.isEmpty ? "仕事中" : settings.clockIn.text
        )
        let client = SlackStatusClient(transport: model.transport)
        let results = await client.setStatus(status, tokens: SpaceDelimited.toList(token))
        if let failure = results.first(where: { !$0.success }) {
            result = "失敗: \(failure.detail ?? "")"
            isError = true
        } else if results.isEmpty {
            result = "トークンが未設定です"
            isError = true
        } else {
            result = "ステータスを更新しました"
            isError = false
        }
    }
}
