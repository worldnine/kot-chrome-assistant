import AppKit
import SwiftUI

/// メニューバーから開くポップオーバー。Myレコーダーをそのまま表示する。
struct PopoverView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if model.recorder.status == .notLoggedIn {
                notLoggedInNotice
            }

            RecorderWebHostView(controller: model.recorder)
                .frame(width: 480, height: 480)

            footer
        }
        .onAppear {
            model.recorder.refreshIfSettingsChanged()
        }
        .onDisappear {
            model.recorder.park()
        }
    }

    private var notLoggedInNotice: some View {
        Text("Myレコーダーへのログインが必要です。下の画面からログインしてください。")
            .font(.callout)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(.yellow.opacity(0.2))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Label(model.recorder.statusDescription, systemImage: model.recorder.menuBarSymbol)
                .font(.callout)

            Spacer()

            Button("再読み込み") {
                model.recorder.loadRecorder()
            }

            Button("ブラウザで開く") {
                model.recorder.openInBrowser()
            }

            SettingsLink {
                Text("設定…")
            }

            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
        }
        .controlSize(.small)
        .padding(8)
    }
}

/// 常駐 WKWebView をポップオーバー内に表示するホスト。
/// 同一インスタンスを keeper ウィンドウと行き来させる（生成し直さない）。
struct RecorderWebHostView: NSViewRepresentable {
    let controller: RecorderWebController

    final class Coordinator {
        let controller: RecorderWebController

        init(controller: RecorderWebController) {
            self.controller = controller
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> NSView {
        NSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        controller.attach(to: nsView)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.controller.park()
    }
}
