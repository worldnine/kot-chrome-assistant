import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPRequest: Equatable, Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?

    public init(method: String = "POST", url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let body: Data

    public init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    public var isSuccess: Bool { (200..<300).contains(statusCode) }
    public var bodyText: String { String(data: body, encoding: .utf8) ?? "" }
}

public protocol HTTPTransport: Sendable {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Linux の corelibs-foundation でも使えるよう continuation ベースで実装
        let (data, statusCode): (Data, Int) = try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                continuation.resume(returning: (data ?? Data(), http.statusCode))
            }
            task.resume()
        }
        return HTTPResponse(statusCode: statusCode, body: data)
    }
}

/// JSON ボディの POST リクエスト構築
public enum JSONRequest {
    public static func post(_ url: URL, json: [String: Any], bearerToken: String? = nil) -> HTTPRequest {
        var headers = ["Content-Type": "application/json; charset=utf-8"]
        if let bearerToken {
            headers["Authorization"] = "Bearer \(bearerToken)"
        }
        let body = try? JSONSerialization.data(withJSONObject: json)
        return HTTPRequest(url: url, headers: headers, body: body)
    }
}
