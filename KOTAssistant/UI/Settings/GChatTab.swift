import KOTCore
import KOTNotifications
import SwiftUI

/// Google Chat 連携（Webhook 通知＋ユーザー認証投稿）。変更は即時保存。
struct GChatTab: View {
    let model: AppModel

    @State private var form = FormState()
    @State private var loaded = false
    @State private var connected: Bool?
    @State private var busy = false
    @State private var setupInput = ""
    @State private var webhookResult = ""
    @State private var webhookIsError = false
    @State private var userResult = ""
    @State private var userIsError = false

    struct FormState: Equatable {
        var webhook = GoogleChatWebhookSettings()
        var user = GoogleChatUserSettings()
        var webhookURLs = ""
        var spaces = ""
        var clientSecret = ""
    }

    var body: some View {
        Form {
            Section {
                Toggle("Webhook 通知", isOn: $form.webhook.enabled)
            } footer: {
                Text("スペースの Incoming Webhook へボット名義で投稿します。URL はスペース区切りで複数指定できます。")
            }

            Section {
                TextField("Webhook URL", text: $form.webhookURLs)
                MessageFields(
                    clockIn: $form.webhook.clockInMessage,
                    clockOut: $form.webhook.clockOutMessage,
                    breakStart: $form.webhook.breakStartMessage,
                    breakEnd: $form.webhook.breakEndMessage
                )
                HStack {
                    Button("テスト送信") { Task { await testWebhook() } }
                    ResultText(text: webhookResult, isError: webhookIsError)
                }
            }
            .disabled(!form.webhook.enabled)

            Section {
                Toggle("ユーザー認証投稿", isOn: $form.user.enabled)
            } footer: {
                Text("OAuth で接続し、自分のアイコン・名前で投稿します。スペース ID は spaces/XXXX・素の ID・チャット URL のいずれの形式でも、スペース区切りで複数指定できます。")
            }

            Section {
                TextField("OAuth Client ID", text: $form.user.oauthClientID)
                SecureField("OAuth Client Secret", text: $form.clientSecret)
                TextField("スペース ID", text: $form.spaces, prompt: Text("spaces/AAAA または チャット URL"))
                LabeledContent("接続状態") {
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
                MessageFields(
                    clockIn: $form.user.clockInMessage,
                    clockOut: $form.user.clockOutMessage,
                    breakStart: $form.user.breakStartMessage,
                    breakEnd: $form.user.breakEndMessage
                )
                HStack {
                    Button("テスト送信") { Task { await testUser() } }
                        .disabled(busy)
                    ResultText(text: userResult, isError: userIsError)
                }
            }
            .disabled(!form.user.enabled)

            Section("セットアップ URL の取り込み") {
                TextField("セットアップ URL または base64 コード", text: $setupInput)
                Button("取り込み") { importSetup() }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            load()
            Task { await checkConnection() }
        }
        .onChange(of: form) { save() }
    }

    private func load() {
        let settings = model.settingsStore.load()
        form.webhook = settings.googleChatWebhook
        form.user = settings.googleChatUser
        form.webhookURLs = SpaceDelimited.toText(settings.googleChatWebhook.webhookURLs)
        form.spaces = SpaceDelimited.toText(settings.googleChatUser.spaces)
        form.clientSecret = model.secret(.googleChatOAuthClientSecret)
        loaded = true
    }

    private func save() {
        guard loaded else { return }
        var settings = model.settingsStore.load()
        var webhook = form.webhook
        webhook.webhookURLs = SpaceDelimited.toList(form.webhookURLs)
        var user = form.user
        user.spaces = SpaceDelimited.toList(form.spaces)
        settings.googleChatWebhook = webhook
        settings.googleChatUser = user
        model.settingsStore.save(settings)
        model.setSecret(form.clientSecret, for: .googleChatOAuthClientSecret)
    }

    private func checkConnection() async {
        guard !form.user.oauthClientID.isEmpty, !form.clientSecret.isEmpty else {
            connected = false
            return
        }
        connected = await model.oauth.checkConnection(clientID: form.user.oauthClientID, clientSecret: form.clientSecret)
    }

    private func connect() async {
        guard !form.user.oauthClientID.isEmpty, !form.clientSecret.isEmpty else {
            userResult = "Client ID と Client Secret を入力してください"
            userIsError = true
            return
        }
        busy = true
        defer { busy = false }
        do {
            let authorizer = GoogleLoopbackAuthorizer(oauth: model.oauth)
            _ = try await authorizer.authorize(clientID: form.user.oauthClientID, clientSecret: form.clientSecret)
            connected = true
            userResult = "接続しました"
            userIsError = false
        } catch {
            connected = false
            userResult = "接続失敗: \(error.localizedDescription)"
            userIsError = true
        }
    }

    private func disconnect() async {
        busy = true
        defer { busy = false }
        await model.oauth.disconnect()
        // 誤送信防止のため連携フラグも OFF にする（原拡張と同じ）
        form.user.enabled = false
        connected = false
        userResult = "切断しました"
        userIsError = false
    }

    private func testUser() async {
        guard !form.user.oauthClientID.isEmpty, !form.clientSecret.isEmpty, !form.spaces.isEmpty else {
            userResult = "Client ID / Client Secret / スペース ID を入力してください"
            userIsError = true
            return
        }
        busy = true
        defer { busy = false }
        let text = form.user.clockInMessage.isEmpty ? "テスト" : form.user.clockInMessage
        let client = GoogleChatUserClient(transport: model.transport, oauth: model.oauth)
        let results = await client.postBatch(
            text: text,
            spaces: SpaceDelimited.toList(form.spaces),
            clientID: form.user.oauthClientID,
            clientSecret: form.clientSecret,
            allowInteractive: true
        )
        if let failure = results.first(where: { !$0.success }) {
            userResult = "失敗 (\(failure.destination)): \(failure.detail ?? "")"
            userIsError = true
        } else {
            userResult = "送信しました"
            userIsError = false
        }
    }

    private func testWebhook() async {
        let text = form.webhook.clockInMessage.isEmpty ? "テスト" : form.webhook.clockInMessage
        let client = GoogleChatWebhookClient(transport: model.transport)
        let results = await client.post(text: text, webhookURLs: SpaceDelimited.toList(form.webhookURLs))
        if let failure = results.first(where: { !$0.success }) {
            webhookResult = "失敗: \(failure.detail ?? "")"
            webhookIsError = true
        } else if results.isEmpty {
            webhookResult = "Webhook URL が未設定です"
            webhookIsError = true
        } else {
            webhookResult = "送信しました"
            webhookIsError = false
        }
    }

    private func importSetup() {
        switch model.importSetup(from: setupInput) {
        case .success:
            load()
            Task { await checkConnection() }
            setupInput = ""
            userResult = "設定をインポートしました。「Google に接続」で認証してください。"
            userIsError = false
        case .failure(let error):
            userResult = "取り込み失敗: \(error.localizedDescription)"
            userIsError = true
        }
    }
}
