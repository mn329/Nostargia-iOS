@preconcurrency import FirebaseFirestore
import Foundation
import NostargiaKit

/// users/{uid}/stars
final class FirestoreStarRepository: StarRepository, @unchecked Sendable {
    private let collection: CollectionReference

    init(uid: String, db: Firestore = .firestore()) {
        collection = db.collection("users").document(uid).collection("stars")
    }

    func stars() -> AsyncThrowingStream<[Star], Error> {
        let query = collection.order(by: "displayDate")
        return AsyncThrowingStream { continuation in
            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot else { return }
                // 書き込み直後でまだサーバー時刻が無いものは推定値を使う
                let stars = snapshot.documents.compactMap {
                    FirestoreStarMapping.star(id: $0.documentID, data: $0.data(with: .estimate))
                }
                continuation.yield(stars)
            }
            nonisolated(unsafe) let listener = registration
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// オフラインでもすぐに返る（送信は通信が戻ってから Firestore が行う）
    func add(_ draft: StarDraft) async throws -> String {
        let document = collection.document()
        document.setData(FirestoreStarMapping.data(from: draft), completion: nil)
        return document.documentID
    }

    func delete(ids: [String]) async throws {
        let batch = collection.firestore.batch()
        for id in ids {
            batch.deleteDocument(collection.document(id))
        }
        try await batch.commit()
    }
}
