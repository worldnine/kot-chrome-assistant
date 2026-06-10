import Foundation
import Testing
@testable import KOTCore

@Suite struct PKCETests {
    @Test func challengeMatchesRFC7636Vector() {
        // RFC 7636 Appendix B の既知ベクタ
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        #expect(PKCE.challenge(for: verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func verifierIsBase64URL() {
        let pkce = PKCE()
        // 32 バイト → base64url 43 文字、URL 安全文字のみ
        #expect(pkce.codeVerifier.count == 43)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        #expect(pkce.codeVerifier.unicodeScalars.allSatisfy { allowed.contains($0) })
        #expect(pkce.codeChallengeMethod == "S256")
    }

    @Test func challengeDerivedFromVerifier() {
        let pkce = PKCE()
        #expect(pkce.codeChallenge == PKCE.challenge(for: pkce.codeVerifier))
    }
}
