import NostargiaKit
import XCTest
@testable import Nostargia

final class FirebaseAuthServiceTests: XCTestCase {
    let auth = FirebaseAuthService()

    override func tearDown() async throws {
        try? auth.signOut()
    }

    func testSignUpSignOutSignIn() async throws {
        let email = EmulatorSupport.freshEmail()
        let user = try await auth.signUp(email: email, password: EmulatorSupport.password)
        XCTAssertEqual(user.email, email)
        XCTAssertEqual(user.providers, [.password])
        XCTAssertEqual(auth.currentUser?.uid, user.uid)

        try auth.signOut()
        XCTAssertNil(auth.currentUser)

        let again = try await auth.signIn(email: email, password: EmulatorSupport.password)
        XCTAssertEqual(again.uid, user.uid)
    }

    func testFailuresAreTranslated() async throws {
        let email = EmulatorSupport.freshEmail()
        _ = try await auth.signUp(email: email, password: EmulatorSupport.password)
        try auth.signOut()

        await assertFailure(.invalidCredential) { _ = try await self.auth.signIn(email: email, password: "wrong-password") }
        await assertFailure(.emailAlreadyInUse) { _ = try await self.auth.signUp(email: email, password: EmulatorSupport.password) }
        await assertFailure(.weakPassword) { _ = try await self.auth.signUp(email: EmulatorSupport.freshEmail(), password: "123") }
        await assertFailure(.invalidEmail) { _ = try await self.auth.signUp(email: "not-an-email", password: EmulatorSupport.password) }
    }

    func testPasswordResetAndChange() async throws {
        let email = EmulatorSupport.freshEmail()
        _ = try await auth.signUp(email: email, password: EmulatorSupport.password)
        try await auth.sendPasswordReset(email: email)
        try await auth.updatePassword("newpassword456")
        try await auth.requestEmailChange(to: EmulatorSupport.freshEmail())
        try auth.signOut()
        _ = try await auth.signIn(email: email, password: "newpassword456")
    }

    func testAuthStatesFollowSignInAndOut() async throws {
        let states = auth.authStates()
        var iterator = states.makeAsyncIterator()
        _ = await iterator.next()
        let user = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)
        var seen = await iterator.next()
        XCTAssertEqual(seen??.uid, user.uid)
        try auth.signOut()
        seen = await iterator.next()
        XCTAssertNil(seen ?? nil)
    }

    func testDeleteAccountRemovesDataAndUser() async throws {
        let email = EmulatorSupport.freshEmail()
        let user = try await auth.signUp(email: email, password: EmulatorSupport.password)
        let profiles = FirestoreProfileRepository(uid: user.uid)
        try await profiles.create(UserProfile(userName: "みなと", birthday: Date(timeIntervalSince1970: 0)))

        try await profiles.deleteAllData()
        try await auth.deleteAccount(appleAuthorizationCode: nil)
        XCTAssertNil(auth.currentUser)

        // 同じメールアドレスでもう一度登録できる = 認証のユーザーも消えている
        _ = try await auth.signUp(email: email, password: EmulatorSupport.password)
    }

    private func assertFailure(_ expected: AuthFailure, file: StaticString = #filePath, line: UInt = #line, _ body: () async throws -> Void) async {
        do {
            try await body()
            XCTFail("\(expected) が投げられなかった", file: file, line: line)
        } catch let failure as AuthFailure {
            XCTAssertEqual(failure, expected, file: file, line: line)
        } catch {
            XCTFail("AuthFailure ではないエラー: \(error)", file: file, line: line)
        }
    }
}
