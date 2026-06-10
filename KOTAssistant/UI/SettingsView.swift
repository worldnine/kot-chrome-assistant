import SwiftUI

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralTab(model: model)
                .tabItem { Label("全般", systemImage: "gearshape") }
            SlackTab(model: model)
                .tabItem { Label("Slack 通知", systemImage: "message") }
            SlackStatusTab(model: model)
                .tabItem { Label("Slack ステータス", systemImage: "face.smiling") }
            GChatWebhookTab(model: model)
                .tabItem { Label("Google Chat", systemImage: "bubble.left") }
            GChatUserTab(model: model)
                .tabItem { Label("Google Chat (ユーザー)", systemImage: "person.crop.circle.badge.checkmark") }
        }
        .frame(width: 600)
        .padding(.bottom, 8)
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
