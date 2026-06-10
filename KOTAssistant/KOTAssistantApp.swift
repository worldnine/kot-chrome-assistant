import AppIntents
import AppKit
import KOTCore
import KOTNotifications
import Observation
import OSLog
import SwiftUI

/// 依存オブジェクトのコンテナ。
/// App Intents（別経路で起動される）からも同一インスタンスへ到達できるよう singleton。
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    @ObservationIgnored let transport: URLSessionTransport
    @ObservationIgnored let secrets: KeychainSecretStore
    @ObservationIgnored let settingsStore: SettingsStore
    @ObservationIgnored let oauth: GoogleOAuthService
    @ObservationIgnored let dispatcher: NotificationDispatcher
    let recorder: RecorderWebController

    private init() {
        let transport = URLSessionTransport()
        let secrets = KeychainSecretStore()
        let settingsStore = SettingsStore(store: UserDefaultsStore())
        let oauth = GoogleOAuthService(transport: transport, secrets: secrets)
        let dispatcher = NotificationDispatcher(transport: transport, oauth: oauth, secrets: secrets) { category, message in
            Logger(subsystem: "jp.co.infosign.KOTAssistant", category: category)
                .error("\(message, privacy: .public)")
        }

        self.transport = transport
        self.secrets = secrets
        self.settingsStore = settingsStore
        self.oauth = oauth
        self.dispatcher = dispatcher
        self.recorder = RecorderWebController(settingsStore: settingsStore, dispatcher: dispatcher)
    }

    // MARK: - シークレットの簡易アクセス（設定 UI 用）

    func secret(_ key: SecretKey) -> String {
        ((try? secrets.secret(for: key)) ?? nil) ?? ""
    }

    func setSecret(_ value: String, for key: SecretKey) {
        if value.isEmpty {
            try? secrets.removeSecret(for: key)
        } else {
            try? secrets.setSecret(value, for: key)
        }
    }

    /// スペース区切りシークレット（複数ワークスペースのトークン等）をリスト化
    func secretList(_ key: SecretKey) -> [String] {
        secret(key).split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    // MARK: - セットアップ取り込み

    /// セットアップ URL / base64 を取り込む。clientSecret は Keychain へ。
    @discardableResult
    func importSetup(from input: String) -> Result<SetupConfig, Error> {
        do {
            let config = try SetupConfig.parse(input)
            var settings = settingsStore.load()
            config.apply(to: &settings.googleChatUser)
            settingsStore.save(settings)
            if let clientSecret = config.clientSecret, !clientSecret.isEmpty {
                setSecret(clientSecret, for: .googleChatOAuthClientSecret)
            }
            return .success(config)
        } catch {
            return .failure(error)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// kotassistant://setup?d=BASE64 によるセットアップ取り込み
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "kotassistant" {
            AppModel.shared.importSetup(from: url.absoluteString)
        }
    }
}

@main
struct KOTAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var model: AppModel

    init() {
        let model = AppModel.shared
        _model = State(initialValue: model)
        AppDependencyManager.shared.add(dependency: model.recorder)
        Task {
            await model.oauth.setAuthorizer(GoogleLoopbackAuthorizer(oauth: model.oauth))
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            Image(systemName: model.recorder.menuBarSymbol)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
