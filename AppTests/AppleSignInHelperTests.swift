import XCTest
@testable import Nostargia

@MainActor
final class AppleSignInHelperTests: XCTestCase {
    func testNonceHasRequestedLengthAndSafeCharacters() {
        let allowed = Set("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = AppleSignInHelper.randomNonce()
        XCTAssertEqual(nonce.count, 32)
        XCTAssertTrue(nonce.allSatisfy(allowed.contains))
        XCTAssertNotEqual(nonce, AppleSignInHelper.randomNonce())
    }

    func testSHA256MatchesKnownVector() {
        XCTAssertEqual(AppleSignInHelper.sha256("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}
