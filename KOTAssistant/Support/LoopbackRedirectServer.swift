import Foundation
import Network

/// OAuth2 のリダイレクトを受けるワンショット HTTP サーバ（127.0.0.1 の空きポート）。
/// Google の Web/デスクトップクライアントはカスタム URL スキームを受け付けないため
/// ループバック方式を使う。
final class LoopbackRedirectServer: @unchecked Sendable {
    enum ServerError: Error, CustomLocalizedStringResourceConvertible {
        case badRequest
        case denied(String)

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .badRequest:
                return "不正なリダイレクトリクエストを受信しました。"
            case .denied(let reason):
                return "認証が完了しませんでした: \(reason)"
            }
        }
    }

    /// 既定の待ち受けポート。
    /// 「ウェブアプリケーション」タイプの OAuth クライアントはリダイレクト URI が
    /// ポート込みで完全一致する必要があるため、登録可能な固定ポートを優先する
    /// （クライアント側には http://127.0.0.1:51789 を登録してもらう）。
    static let preferredPort: UInt16 = 51789

    private let listener: NWListener
    private let queue = DispatchQueue(label: "jp.co.infosign.KOTAssistant.loopback")
    private let lock = NSLock()
    private var readyContinuation: CheckedContinuation<UInt16, Error>?
    private var codeContinuation: CheckedContinuation<String, Error>?

    init(fixedPort: UInt16? = nil) throws {
        let parameters = NWParameters.tcp
        parameters.requiredInterfaceType = .loopback
        parameters.allowLocalEndpointReuse = true
        if let fixedPort, let port = NWEndpoint.Port(rawValue: fixedPort) {
            listener = try NWListener(using: parameters, on: port)
        } else {
            listener = try NWListener(using: parameters)
        }
    }

    /// 固定ポートで待ち受けを試み、使用中なら空きポートにフォールバックして
    /// 開始済みのサーバを返す。
    static func startPreferringFixedPort() async throws -> (server: LoopbackRedirectServer, port: UInt16) {
        if let fixed = try? LoopbackRedirectServer(fixedPort: preferredPort),
           let port = try? await fixed.start() {
            return (fixed, port)
        }
        let fallback = try LoopbackRedirectServer()
        let port = try await fallback.start()
        return (fallback, port)
    }

    /// リッスン開始してポート番号を返す
    func start() async throws -> UInt16 {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock { readyContinuation = continuation }
            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    let port = self?.listener.port?.rawValue ?? 0
                    self?.resumeReady(.success(port))
                case .failed(let error):
                    self?.resumeReady(.failure(error))
                case .cancelled:
                    self?.resumeReady(.failure(ServerError.badRequest))
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    /// 認可コード付きリダイレクトの到着を待つ
    func waitForCode() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock { codeContinuation = continuation }
        }
    }

    func stop() {
        listener.cancel()
        resumeCode(.failure(CancellationError()))
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, _, _ in
            guard let self else {
                connection.cancel()
                return
            }
            let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let result = Self.extractCode(fromHTTPRequest: request)
            let message: String
            switch result {
            case .success:
                message = "認証が完了しました。このウィンドウを閉じてアプリに戻ってください。"
            case .failure:
                message = "認証が完了しませんでした。アプリに戻ってやり直してください。"
            }
            let html = "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>KOT Assistant</title></head><body><p>\(message)</p></body></html>"
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
            connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
                connection.cancel()
                self.resumeCode(result)
            })
        }
    }

    /// `GET /?code=...` から認可コードを取り出す
    static func extractCode(fromHTTPRequest request: String) -> Result<String, Error> {
        guard let firstLine = request.split(separator: "\r\n").first ?? request.split(separator: "\n").first,
              firstLine.hasPrefix("GET ") else {
            return .failure(ServerError.badRequest)
        }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2,
              let components = URLComponents(string: "http://127.0.0.1\(parts[1])") else {
            return .failure(ServerError.badRequest)
        }
        if let code = components.queryItems?.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            return .success(code)
        }
        let reason = components.queryItems?.first(where: { $0.name == "error" })?.value ?? "認可コードがありません"
        return .failure(ServerError.denied(reason))
    }

    private func resumeReady(_ result: Result<UInt16, Error>) {
        let continuation = lock.withLock {
            let c = readyContinuation
            readyContinuation = nil
            return c
        }
        guard let continuation else { return }
        switch result {
        case .success(let port): continuation.resume(returning: port)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }

    private func resumeCode(_ result: Result<String, Error>) {
        let continuation = lock.withLock {
            let c = codeContinuation
            codeContinuation = nil
            return c
        }
        guard let continuation else { return }
        switch result {
        case .success(let code): continuation.resume(returning: code)
        case .failure(let error): continuation.resume(throwing: error)
        }
    }
}
