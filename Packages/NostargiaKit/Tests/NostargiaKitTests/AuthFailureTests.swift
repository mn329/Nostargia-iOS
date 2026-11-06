import Foundation
import Testing
@testable import NostargiaKit

struct AuthFailureTests {
    @Test func mapsFirebaseAuthCodes() {
        #expect(AuthFailure(code: 17007) == .emailAlreadyInUse)
        #expect(AuthFailure(code: 17008) == .invalidEmail)
        #expect(AuthFailure(code: 17009) == .invalidCredential)
        #expect(AuthFailure(code: 17004) == .invalidCredential)
        #expect(AuthFailure(code: 17011) == .invalidCredential)
        #expect(AuthFailure(code: 17026) == .weakPassword)
        #expect(AuthFailure(code: 17020) == .network)
        #expect(AuthFailure(code: 17010) == .tooManyRequests)
        #expect(AuthFailure(code: 17014) == .requiresRecentLogin)
        #expect(AuthFailure(code: 17012) == .accountExistsWithDifferentCredential)
        #expect(AuthFailure(code: 17005) == .userDisabled)
        #expect(AuthFailure(code: 99999) == .unknown(code: 99999))
    }

    @Test func messagesAreJapanese() {
        #expect(AuthFailure.invalidCredential.message == "メールアドレスまたはパスワードが違います。")
        #expect(AuthFailure.unknown(code: 42).message == "エラーが発生しました。（コード: 42）")
    }
}
