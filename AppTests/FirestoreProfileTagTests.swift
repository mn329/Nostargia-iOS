import NostargiaKit
import XCTest
@testable import Nostargia

final class FirestoreProfileTagTests: XCTestCase {
    let auth = FirebaseAuthService()
    let birthday = Date(timeIntervalSince1970: 946_652_400)

    override func tearDown() async throws {
        try? auth.signOut()
    }

    private func signUp() async throws -> String {
        try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password).uid
    }

    func testProfileIsNilBeforeCreation() async throws {
        let uid = try await signUp()
        let profile = try await FirestoreProfileRepository(uid: uid).profile()
        XCTAssertNil(profile)
    }

    func testCreateProfileWithDefaultTags() async throws {
        let uid = try await signUp()
        let profiles = FirestoreProfileRepository(uid: uid)
        try await profiles.create(UserProfile(userName: "みなと", birthday: birthday))

        let profile = try await profiles.profile()
        XCTAssertEqual(profile, UserProfile(userName: "みなと", birthday: birthday))
        let tags = try await FirestoreTagRepository(uid: uid).tags()
        XCTAssertEqual(tags.map(\.name), ["休日", "誕生日", "アニバーサリー"])

        try await profiles.updateUserName("ミナト")
        let renamed = try await profiles.profile()
        XCTAssertEqual(renamed?.userName, "ミナト")
    }

    func testTagCRUD() async throws {
        let uid = try await signUp()
        let tags = FirestoreTagRepository(uid: uid)
        let added = try await tags.add(name: "旅行")
        try await tags.rename(id: added.id, to: "旅")
        var names = try await tags.tags().map(\.name)
        XCTAssertEqual(names, ["旅"])
        try await tags.delete(id: added.id)
        names = try await tags.tags().map(\.name)
        XCTAssertEqual(names, [])
    }

    func testDeleteAllDataIsIdempotent() async throws {
        let uid = try await signUp()
        let profiles = FirestoreProfileRepository(uid: uid)
        try await profiles.create(UserProfile(userName: "みなと", birthday: birthday))
        var random = SystemRandomSource()
        let draft = StarComposer.draft(
            entry: DiaryEntry(mood: .neutral, goodThings: [], tag: nil), existing: [], letter: nil, now: Date(), random: &random
        )
        let stars = FirestoreStarRepository(uid: uid)
        _ = try await stars.add(draft)
        _ = try await EmulatorSupport.firstValue(of: stars.stars()) { $0.count == 1 }

        try await profiles.deleteAllData()
        try await profiles.deleteAllData()

        let profile = try await profiles.profile()
        XCTAssertNil(profile)
        let remainingTags = try await FirestoreTagRepository(uid: uid).tags()
        XCTAssertEqual(remainingTags, [])
        _ = try await EmulatorSupport.firstValue(of: stars.stars()) { $0.isEmpty }
    }
}
