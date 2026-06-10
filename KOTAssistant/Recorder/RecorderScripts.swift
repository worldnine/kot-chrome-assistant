import Foundation
import WebKit

enum RecorderScripts {
    static func bridgeScript() -> WKUserScript? {
        guard let url = Bundle.main.url(forResource: "kot_bridge", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    }
}

/// WKScriptMessageHandler は nonisolated だが配信は常にメインスレッドなので、
/// MainActor 隔離のコントローラへ橋渡しする。
final class ScriptMessageRouter: NSObject, WKScriptMessageHandler {
    private let onMessage: @MainActor (String, Any) -> Void

    init(onMessage: @escaping @MainActor (String, Any) -> Void) {
        self.onMessage = onMessage
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let name = message.name
        let body = message.body
        MainActor.assumeIsolated {
            onMessage(name, body)
        }
    }
}
