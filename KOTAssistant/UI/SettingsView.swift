import SwiftUI

/// 設定ウィンドウ。macOS の流儀に合わせ、保存ボタンなしの即時反映。
/// ウィンドウは固定サイズで、各タブのフォームがスクロールする（System Settings と同じ）。
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralTab(model: model)
                .tabItem { Label("全般", systemImage: "gearshape") }
            SlackTab(model: model)
                .tabItem { Label("Slack", systemImage: "message") }
            GChatTab(model: model)
                .tabItem { Label("Google Chat", systemImage: "bubble.left") }
        }
        .frame(width: 700, height: 580)
    }
}

/// 機能の有効/無効を切り替えるヘッダ行（System Settings の機能ページの形）。
/// タイトル・説明・大きめのスイッチで、ON/OFF がひと目でわかるようにする。
struct FeatureToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.large)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

/// スペース区切り文字列 ↔ リストの変換（拡張時代の入力形式を踏襲）
enum SpaceDelimited {
    static func toList(_ text: String) -> [String] {
        text.split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    static func toText(_ list: [String]) -> String {
        list.joined(separator: " ")
    }
}

/// テスト送信などの結果表示
struct ResultText: View {
    let text: String
    let isError: Bool

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(isError ? .red : .secondary)
            .lineLimit(2)
    }
}

/// 打刻アクションごとのメッセージ入力（各連携で共通のパターン）
struct MessageFields: View {
    @Binding var clockIn: String
    @Binding var clockOut: String
    @Binding var breakStart: String
    @Binding var breakEnd: String

    var body: some View {
        TextField("出勤", text: $clockIn)
        TextField("退勤", text: $clockOut)
        TextField("休憩開始", text: $breakStart)
        TextField("休憩終了", text: $breakEnd)
    }
}
