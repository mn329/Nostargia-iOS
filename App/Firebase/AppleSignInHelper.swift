import AuthenticationServices
import CryptoKit
@preconcurrency import FirebaseAuth
import Foundation

struct AppleSignInResult {
    let credential: AuthCredential
    /// アカウント削除時に Apple の認証を取り消すために使う
    let authorizationCode: String?
}

enum AppleSignInError: Error {
    case missingNonce
    case missingIdentityToken
    case unexpectedCredential
}

/// Apple でサインイン。prepare でリクエストに nonce を付け、結果から Firebase の資格情報を作る
@MainActor
final class AppleSignInHelper {
    private var currentNonce: String?

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func credential(from authorization: ASAuthorization) throws -> AppleSignInResult {
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppleSignInError.unexpectedCredential
        }
        guard let nonce = currentNonce else { throw AppleSignInError.missingNonce }
        guard let tokenData = apple.identityToken, let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleSignInError.missingIdentityToken
        }
        let credential = OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: nonce, fullName: apple.fullName)
        let code = apple.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        return AppleSignInResult(credential: credential, authorizationCode: code)
    }

    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes に失敗しました: \(status)")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
