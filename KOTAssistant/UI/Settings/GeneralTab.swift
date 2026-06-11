import KOTCore
import ServiceManagement
import SwiftUI

struct GeneralTab: View {
    let model: AppModel

    @State private var form = FormState()
    @State private var loaded = false
    @State private var loginItemError: String?

    struct FormState: Equatable {
        var domain: KOTDomain = .s2
        var authMode: KOTAuthMode = .account
        var debugLogging = false
        var launchAtLogin = false
    }

    var body: some View {
        Form {
            Section {
                Toggle("ログイン時に KOT Assistant を起動", isOn: $form.launchAtLogin)
                if let loginItemError {
                    ResultText(text: loginItemError, isError: true)
                }
            } footer: {
                Text("メニューバーに常駐するアプリなので、自動起動をおすすめします。")
            }

            Section("KING OF TIME") {
                Picker("ドメイン", selection: $form.domain) {
                    Text("s2.ta.kingoftime.jp").tag(KOTDomain.s2)
                    Text("s3.ta.kingoftime.jp").tag(KOTDomain.s3)
                    Text("s4.ta.kingoftime.jp").tag(KOTDomain.s4)
                }
                Picker("認証方式", selection: $form.authMode) {
                    Text("ID / パスワード").tag(KOTAuthMode.account)
                    Text("SAML（シングルサインオン）").tag(KOTAuthMode.saml)
                }
            }

            Section {
                Toggle("デバッグログを出力する", isOn: $form.debugLogging)
            }

            Section("ターミナルから使う") {
                Text("ショートカット.app でこのアプリのアクション（打刻状況など）を包むショートカットを作ると、shortcuts run \"打刻状況\" のように実行できます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { load() }
        .onChange(of: form) { save() }
    }

    private func load() {
        let settings = model.settingsStore.load()
        form.domain = settings.recorder.domain
        form.authMode = settings.recorder.authMode
        form.debugLogging = settings.debugLogging
        form.launchAtLogin = SMAppService.mainApp.status == .enabled
        loaded = true
    }

    private func save() {
        guard loaded else { return }
        var settings = model.settingsStore.load()
        settings.recorder = RecorderSettings(domain: form.domain, authMode: form.authMode)
        settings.debugLogging = form.debugLogging
        model.settingsStore.save(settings)
        model.recorder.refreshIfSettingsChanged()
        applyLaunchAtLogin()
    }

    private func applyLaunchAtLogin() {
        let enabled = SMAppService.mainApp.status == .enabled
        guard form.launchAtLogin != enabled else { return }
        do {
            if form.launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "ログイン項目の変更に失敗しました: \(error.localizedDescription)"
            form.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
