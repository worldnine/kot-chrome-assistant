import KOTCore
import SwiftUI

struct GeneralTab: View {
    let model: AppModel

    @State private var recorder = RecorderSettings()
    @State private var debugLogging = false
    @State private var saved = false

    var body: some View {
        Form {
            Section("KING OF TIME") {
                Picker("ドメイン", selection: $recorder.domain) {
                    Text("s2.ta.kingoftime.jp").tag(KOTDomain.s2)
                    Text("s3.ta.kingoftime.jp").tag(KOTDomain.s3)
                    Text("s4.ta.kingoftime.jp").tag(KOTDomain.s4)
                }
                Picker("認証方式", selection: $recorder.authMode) {
                    Text("ID / パスワード").tag(KOTAuthMode.account)
                    Text("SAML（シングルサインオン）").tag(KOTAuthMode.saml)
                }
            }

            Section {
                Toggle("デバッグログを出力する", isOn: $debugLogging)
            }

            Section {
                HStack {
                    Button("保存") { save() }
                    if saved {
                        ResultText(text: "保存しました", isError: false)
                    }
                }
            }

            Section("ターミナルから使う") {
                Text("App Intents を定義しているので、ショートカット経由でターミナルから打刻できます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(#"shortcuts run "出勤""#)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
        .onAppear { load() }
    }

    private func load() {
        let settings = model.settingsStore.load()
        recorder = settings.recorder
        debugLogging = settings.debugLogging
    }

    private func save() {
        var settings = model.settingsStore.load()
        settings.recorder = recorder
        settings.debugLogging = debugLogging
        model.settingsStore.save(settings)
        model.recorder.refreshIfSettingsChanged()
        saved = true
    }
}
