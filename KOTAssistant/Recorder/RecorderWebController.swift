import AppKit
import Foundation
import KOTCore
import KOTNotifications
import Observation
import WebKit

enum PunchError: Error, CustomLocalizedStringResourceConvertible {
    case notLoggedIn
    case actionUnavailable(PunchAction)
    case bridgeTimeout
    case buttonNotFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notLoggedIn:
            return "KING OF TIME にログインしていません。メニューバーから Myレコーダーを開いてログインしてください。"
        case .actionUnavailable(let action):
            return "現在「\(action.displayName)」は打刻できない状態です。"
        case .bridgeTimeout:
            return "Myレコーダーの読み込みがタイムアウトしました。"
        case .buttonNotFound:
            return "打刻ボタンが見つかりませんでした。"
        }
    }
}

/// 常駐 WKWebView の所有者。
/// ポップオーバーが閉じている間も不可視の keeper ウィンドウに WebView を退避して
/// JS 実行（App Intents からの打刻・状態取得）を可能に保つ。
@MainActor
@Observable
final class RecorderWebController {
    enum Status: Equatable {
        case loading
        case notLoggedIn
        case ready
    }

    private(set) var status: Status = .loading
    private(set) var state: RecorderState?

    let webView: WKWebView

    @ObservationIgnored private let keeperWindow: NSWindow
    @ObservationIgnored private let settingsStore: SettingsStore
    @ObservationIgnored private let dispatcher: NotificationDispatcher
    @ObservationIgnored private var router: ScriptMessageRouter?
    @ObservationIgnored private var loadedURL: URL?
    @ObservationIgnored private var stateWaiters: [StateWaiter] = []

    private final class StateWaiter {
        var continuation: CheckedContinuation<Void, Never>?

        init(continuation: CheckedContinuation<Void, Never>) {
            self.continuation = continuation
        }

        func resume() {
            continuation?.resume()
            continuation = nil
        }
    }

    init(settingsStore: SettingsStore, dispatcher: NotificationDispatcher) {
        self.settingsStore = settingsStore
        self.dispatcher = dispatcher

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        self.webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 480, height: 480),
            configuration: configuration
        )

        let keeper = NSWindow(
            contentRect: NSRect(x: -4000, y: -4000, width: 480, height: 480),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        keeper.isReleasedWhenClosed = false
        keeper.alphaValue = 0
        keeper.ignoresMouseEvents = true
        keeper.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        self.keeperWindow = keeper

        let router = ScriptMessageRouter { [weak self] name, body in
            self?.handleMessage(name: name, body: body)
        }
        self.router = router

        let contentController = webView.configuration.userContentController
        contentController.add(router, name: "kotState")
        contentController.add(router, name: "kotPunch")
        if let script = RecorderScripts.bridgeScript() {
            contentController.addUserScript(script)
        }

        park()
        loadRecorder()
    }

    // MARK: - 表示

    /// ポップオーバー表示時に WebView を表示用コンテナへ移す
    func attach(to container: NSView) {
        guard webView.superview != container else { return }
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
    }

    /// ポップオーバーが閉じたら keeper ウィンドウへ退避（JS 実行を継続させる）
    func park() {
        guard webView.superview != keeperWindow.contentView else { return }
        webView.removeFromSuperview()
        webView.frame = keeperWindow.contentView?.bounds ?? .zero
        keeperWindow.contentView?.addSubview(webView)
        keeperWindow.orderBack(nil)
    }

    var menuBarSymbol: String {
        guard status == .ready, let state else { return "deskclock" }
        if state.onBreak { return "cup.and.saucer.fill" }
        if state.isClockedOut { return "moon.zzz.fill" }
        if state.isClockedIn { return "deskclock.fill" }
        return "deskclock"
    }

    var statusDescription: String {
        switch status {
        case .loading: return "読み込み中…"
        case .notLoggedIn: return "未ログイン"
        case .ready:
            guard let state else { return "状態不明" }
            if state.onBreak { return "休憩中" }
            if state.isClockedOut { return "退勤済み" }
            if state.isClockedIn { return "勤務中" }
            return "未出勤"
        }
    }

    // MARK: - 読み込み

    func loadRecorder() {
        let url = settingsStore.load().recorder.url
        loadedURL = url
        status = .loading
        state = nil
        webView.load(URLRequest(url: url))
    }

    /// 設定（ドメイン・認証方式）が変わっていたら再読み込み
    func refreshIfSettingsChanged() {
        let url = settingsStore.load().recorder.url
        if url != loadedURL {
            loadRecorder()
        }
    }

    func openInBrowser() {
        NSWorkspace.shared.open(settingsStore.load().recorder.url)
    }

    // MARK: - 打刻（App Intents / UI から）

    func punch(_ action: PunchAction) async throws -> RecorderState {
        try await ensureReady()
        guard let current = state else { throw PunchError.bridgeTimeout }
        guard RecorderStateEngine.isActionAvailable(action, state: current) else {
            throw PunchError.actionUnavailable(action)
        }
        let clicked = try await evaluateBool("window.__kotPunch('\(action.rawValue)')")
        guard clicked else { throw PunchError.buttonNotFound }
        // ブリッジが打刻後に状態を再送してくる
        await waitForStateUpdate(timeout: .seconds(5))
        return state ?? current
    }

    func currentState() async throws -> RecorderState {
        try await ensureReady()
        try? await evaluate("window.__kotReadState()")
        await waitForStateUpdate(timeout: .seconds(3))
        guard status == .ready, let state else { throw PunchError.notLoggedIn }
        return state
    }

    private func ensureReady() async throws {
        refreshIfSettingsChanged()
        if status == .ready { return }
        if status == .notLoggedIn {
            // ブラウザ等でログインし直した可能性があるので再読込して確認
            loadRecorder()
        }
        for _ in 0..<30 {
            await waitForStateUpdate(timeout: .milliseconds(500))
            if status == .ready { return }
            if status == .notLoggedIn { throw PunchError.notLoggedIn }
        }
        if status == .notLoggedIn { throw PunchError.notLoggedIn }
        throw PunchError.bridgeTimeout
    }

    // MARK: - ブリッジメッセージ処理

    private func handleMessage(name: String, body: Any) {
        switch name {
        case "kotState":
            guard let dict = body as? [String: Any] else { return }
            if dict["notLoggedIn"] as? Bool == true {
                status = .notLoggedIn
                state = nil
            } else if let settingJSON = dict["setting"] as? String {
                applySnapshot(settingJSON: settingJSON, historyJSON: dict["history"] as? String)
            }
            resumeStateWaiters()

        case "kotPunch":
            guard let dict = body as? [String: Any],
                  let raw = dict["action"] as? String,
                  let action = PunchAction(rawValue: raw) else { return }
            let settings = settingsStore.load()
            let dispatcher = dispatcher
            Task.detached {
                await dispatcher.dispatch(action, settings: settings)
            }

        default:
            break
        }
    }

    private func applySnapshot(settingJSON: String, historyJSON: String?) {
        do {
            let snapshot = try RecorderSnapshot(
                settingJSON: Data(settingJSON.utf8),
                historyJSON: historyJSON.map { Data($0.utf8) }
            )
            let newState = RecorderStateEngine.state(
                history: snapshot.history,
                today: RecorderStateEngine.dayStamp()
            )
            state = newState
            status = .ready
            updateButtonDimming(for: newState)
        } catch {
            // SETTING が想定外の形式でもポップオーバー表示自体は継続する
            status = .ready
        }
    }

    /// 打刻済みボタンの減光（原拡張の opacity 0.3 と同じ見た目）
    private func updateButtonDimming(for state: RecorderState) {
        for action in PunchAction.allCases {
            let available = RecorderStateEngine.isActionAvailable(action, state: state)
            let script = "window.__kotSetButtonDimmed('\(action.rawValue)', \(available ? "false" : "true"))"
            Task { try? await evaluate(script) }
        }
    }

    // MARK: - 状態待ち

    private func waitForStateUpdate(timeout: Duration) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let waiter = StateWaiter(continuation: continuation)
            stateWaiters.append(waiter)
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.timeout(waiter)
            }
        }
    }

    private func resumeStateWaiters() {
        let waiters = stateWaiters
        stateWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func timeout(_ waiter: StateWaiter) {
        stateWaiters.removeAll { $0 === waiter }
        waiter.resume()
    }

    // MARK: - JS 実行

    @discardableResult
    private func evaluate(_ script: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Any?, Error>) in
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }

    private func evaluateBool(_ script: String) async throws -> Bool {
        let result = try await evaluate(script)
        if let bool = result as? Bool { return bool }
        if let number = result as? NSNumber { return number.boolValue }
        return false
    }
}
