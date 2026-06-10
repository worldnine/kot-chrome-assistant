import Foundation

/// Google Chat スペース ID の正規化。
/// 3 形式を受け付ける: `spaces/XXX` / `XXX` / `https://chat.google.com/room/XXX`
public enum SpaceID {
    public static func normalize(_ input: String) -> String {
        if let range = input.range(of: #"chat\.google\.com/room/([A-Za-z0-9_-]+)"#, options: .regularExpression) {
            let matched = String(input[range])
            return String(matched.split(separator: "/").last!)
        }
        if input.hasPrefix("spaces/") {
            return String(input.dropFirst("spaces/".count))
        }
        return input
    }
}
