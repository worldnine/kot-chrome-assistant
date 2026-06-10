import KOTCore
import KOTNotifications
import SwiftUI

struct GChatUserTab: View {
    let model: AppModel

    @State private var settings = GoogleChatUserSettings()
    @State private var spaces = ""
    @State private var clientSecret = ""
    @State private var connected: Bool?
    @State private var setupInput = ""
    @State private var result = ""
    @State private var isError = false
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                Toggle("Google Chat ユーザー認証通知を有効にする", isOn: $settings.enabled)
                TextField("OAuth Client ID", text: $settings.oauthClientID)
                SecureField("OAuth Client Secret", text: $clientSecret)
                TextField("スペース ID（スペース区切りで複数可）", text: $spaces, prompt: Text("spaces/AAAA または チャット URL"))
            }

            Section("Google 接続") {
                HStack {
                    switch connected {
                    case .some(true):
                        Label("接続済み", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .some(false):
                        Label("未接続", systemImage: "circle")
                            .foregroundStyle(.secondary)
                    case .none:
                        Label("確認中…", systemImage: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if connected == true {
                        Button("切断") { Task { await disconnect() } }
                            .disabled(busy)
                    } else {
                        Button("Google に接続") { Task { await connect() } }
                            .disabled(busy)
                    }
                }
            }

            Section("メッセージ（空欄のアクションは通知されません）") {
                TextField("出勤", text: $settings.clockInMessage, prompt: Text(SetupConfig.Defaults.clockIn))
                TextField("退勤", text: $settings.clockOutMessage, prompt: Text(SetupConfig.Defaults.clockOut))
                TextField("休憩開始", text: $settings.breakStartMessage, prompt: Text(SetupConfig.Defaults.breakStart))
                TextField("休憩終了", text: $settings.breakEndMessage, prompt: Text(SetupConfig.Defaults.breakEnd))
            }

            Section("セットアップ URL の取り込み") {
                TextField("セットアップ URL または base64 コード", text: $setupInput)
                Button("取り込み") { importSetup() }
            }

            Section {
                HStack {
                    Button("保存") { save() }
                    Button("テスト送信") { Task { await test() } }
                        .disabled(busy)
                    ResultText(text: result, isError: isError)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            load()
            Task { await checkConnection() }
        }
    }

    private func load() {
        settings = model.settingsStore.load().googleChatUser
        spaces = SpaceDelimited.toText(settings.spaces)
        clientSecret = model.secret(.googleChatOAuthClientSecret)
    }

    private func save() {
        var all = model.settingsStore.load()
        settings.spaces = SpaceDelimited.toList(spaces)
        all.googleChatUser = settings
        model.settingsStore.save(all)
        model.setSecret(clientSecret, for: .googleChatOAuthClientSecret)
        result = "保存しました"
        isError = false
    }

    private func checkConnection() async {
        guard !settings.oauthClientID.isEmpty, !clientSecret.isEmpty else {
            connected = false
            return
        }
        connected = await model.oauth.checkConnection(clientID: settings.oauthClientID, clientSecret: clientSecret)
    }

    private func connect() async {
        guard !settings.oauthClientID.isEmpty, !clientSecret.isEmpty else {
            result = "Client ID と Client Secret を入力してください"
            isError = true
            return
        }
        save()
        busy = true
        defer { busy = false }
        do {
            let authorizer = GoogleLoopbackAuthorizer(oauth: model.oauth)
            _ = try await authorizer.authorize(clientID: settings.oauthClientID, clientSecret: clientSecret)
            connected = true
            result = "接続しました"
            isError = false
        } catch {
            connected = false
            result = "接続失敗: \(error.localizedDescription)"
            isError = true
        }
    }

    private func disconnect() async {
        busy = true
        defer { busy = false }
        await model.oauth.disconnect()
        // 誤送信防止のため連携フラグも OFF にする（原拡張と同じ）
        settings.enabled = false
        save()
        connected = false
        result = "切断しました"
        isError = false
    }

    private func test() async {
        guard !settings.oauthClientID.isEmpty, !clientSecret.isEmpty, !spaces.isEmpty else {
            result = "Client ID / Client Secret / スペース ID を入力してください"
            isError = true
            return
        }
        busy = true
        defer { busy = false }
        let text = settings.clockInMessage.isEmpty ? "テスト" : settings.clockInMessage
        let oauth = model.oauth
        let client = GoogleChatUserClient(transport: model.transport, oauth: oauth)
        let results = await client.postBatch(
            text: text,
            spaces: SpaceDelimited.toList(spaces),
            clientID: settings.oauthClientID,
            clientSecret: clientSecret,
            allowInteractive: true
        )
        if let failure = results.first(where: { !$0.success }) {
            result = "失敗 (\(failure.destination)): \(failure.detail ?? "")"
            isError = true
        } else {
            result = "送信しました"
            isError = false
        }
    }

    private func importSetup() {
        switch model.importSetup(from: setupInput) {
        case .success:
            load()
            setupInput = ""
            result = "設定をインポートしました。「Google に接続」で認証してください。"
            isError = false
        case .failure(let error):
            result = "取り込み失敗: \(error.localizedDescription)"
            isError = true
        }
    }
}
