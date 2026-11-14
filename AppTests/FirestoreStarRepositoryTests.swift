@preconcurrency import FirebaseFirestore
import NostargiaKit
import XCTest
@testable import Nostargia

final class FirestoreStarRepositoryTests: XCTestCase {
    let auth = FirebaseAuthService()

    override func tearDown() async throws {
        try? auth.signOut()
    }

    private func makeDraft(tag: TagRef? = TagRef(id: "t1", name: "休日")) -> StarDraft {
        var random = SystemRandomSource()
        return StarComposer.draft(
            entry: DiaryEntry(mood: MoodValues(all: 80), goodThings: ["散歩", "カフェ"], tag: tag),
            existing: [],
            letter: "星からの手紙",
            now: Date(timeIntervalSince1970: 1_800_000_000),
            random: &random
        )
    }

    func testMappingRoundTrip() {
        let draft = makeDraft()
        var data = FirestoreStarMapping.data(from: draft)
        data["createdAt"] = Timestamp(date: Date(timeIntervalSince1970: 1_800_000_100))
        let star = FirestoreStarMapping.star(id: "s1", data: data)
        XCTAssertEqual(star?.draft, draft)
        XCTAssertEqual(star?.createdAt, Date(timeIntervalSince1970: 1_800_000_100))

        let untagged = makeDraft(tag: nil)
        XCTAssertEqual(FirestoreStarMapping.star(id: "s2", data: FirestoreStarMapping.data(from: untagged))?.tag, nil)
    }

    func testMappingRejectsBrokenDocuments() {
        XCTAssertNil(FirestoreStarMapping.star(id: "x", data: ["scale": 2.0]))
    }

    func testAddObserveDelete() async throws {
        let user = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)
        let repo = FirestoreStarRepository(uid: user.uid)
        let draft = makeDraft()

        let id = try await repo.add(draft)
        let stars = try await EmulatorSupport.firstValue(of: repo.stars()) { $0.count == 1 }
        XCTAssertEqual(stars[0].id, id)
        XCTAssertEqual(stars[0].draft, draft)
        XCTAssertNotNil(stars[0].createdAt)

        try await repo.delete(ids: [id])
        _ = try await EmulatorSupport.firstValue(of: repo.stars()) { $0.isEmpty }
    }

    func testStarsAreOrderedByDisplayDate() async throws {
        let user = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)
        let repo = FirestoreStarRepository(uid: user.uid)
        var later = makeDraft()
        later.displayDate = Date(timeIntervalSince1970: 1_900_000_000)
        _ = try await repo.add(later)
        _ = try await repo.add(makeDraft())

        let stars = try await EmulatorSupport.firstValue(of: repo.stars()) { $0.count == 2 }
        XCTAssertEqual(stars.map(\.displayDate), [Date(timeIntervalSince1970: 1_800_000_000), Date(timeIntervalSince1970: 1_900_000_000)])
    }

    func testCannotReadAnotherUsersStars() async throws {
        let alice = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)
        _ = try await FirestoreStarRepository(uid: alice.uid).add(makeDraft())
        try auth.signOut()
        _ = try await auth.signUp(email: EmulatorSupport.freshEmail(), password: EmulatorSupport.password)

        do {
            _ = try await EmulatorSupport.firstValue(of: FirestoreStarRepository(uid: alice.uid).stars()) { _ in true }
            XCTFail("他人の星が読めてしまった")
        } catch {
            XCTAssertEqual((error as NSError).code, 7) // FirestoreErrorCode permissionDenied
        }
    }
}
