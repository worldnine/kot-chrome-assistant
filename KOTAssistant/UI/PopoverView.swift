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
            // 表示のたびにタイムカード（サーバー正データ）で状態を更新
            Task { try? await model.recorder.refreshServerState() }
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
/// ポップオーバー再表示時に SwiftUI の updateNSView が呼ばれないことがあるため、
/// ウィンドウへの出入り（viewDidMoveToWindow）を基準に attach / park する。
struct RecorderWebHostView: NSViewRepresentable {
    let controller: RecorderWebController

    final class ContainerView: NSView {
        weak var controller: RecorderWebController?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                controller?.attach(to: self)
            } else {
                controller?.park()
            }
        }
    }

    func makeNSView(context: Context) -> ContainerView {
        let view = ContainerView()
        view.controller = controller
        return view
    }

    func updateNSView(_ nsView: ContainerView, context: Context) {
        nsView.controller = controller
        if nsView.window != nil {
            controller.attach(to: nsView)
        }
    }

    static func dismantleNSView(_ nsView: ContainerView, coordinator: ()) {
        nsView.controller?.park()
        nsView.controller = nil
    }
}
