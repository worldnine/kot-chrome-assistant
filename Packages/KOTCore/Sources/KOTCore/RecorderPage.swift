import Foundation

/// KING OF TIME のサブドメイン（契約により異なる）
public enum KOTDomain: String, CaseIterable, Codable, Sendable {
    case s2
    case s3
    case s4
}

/// レコーダーページの認証方式
public enum KOTAuthMode: String, CaseIterable, Codable, Sendable {
    /// ID/パスワードログイン → /recorder/
    case account
    /// SAML ログイン → /recorder2/
    case saml
}

/// Myレコーダーページの URL 構築
public enum RecorderPage {
    public static func url(domain: KOTDomain, authMode: KOTAuthMode) -> URL {
        let recorder = authMode == .saml ? "recorder2" : "recorder"
        return URL(string: "https://\(domain.rawValue).ta.kingoftime.jp/independent/\(recorder)/personal/")!
    }
}
