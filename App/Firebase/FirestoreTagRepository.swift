@preconcurrency import FirebaseFirestore
import Foundation
import NostargiaKit

/// users/{uid}/tags
final class FirestoreTagRepository: TagRepository, @unchecked Sendable {
    private let collection: CollectionReference

    init(uid: String, db: Firestore = .firestore()) {
        collection = db.collection("users").document(uid).collection("tags")
    }

    func tags() async throws -> [Tag] {
        let snapshot = try await collection.order(by: "createdAt").getDocuments()
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let name = data["name"] as? String,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
            else { return nil }
            return Tag(id: document.documentID, name: name, createdAt: createdAt)
        }
    }

    func add(name: String) async throws -> Tag {
        let document = collection.document()
        let createdAt = Date()
        try await document.setData(["name": name, "createdAt": Timestamp(date: createdAt)])
        return Tag(id: document.documentID, name: name, createdAt: createdAt)
    }

    /// 星にコピーしたタグ名は変えない（その日に付けた名前のまま残す）
    func rename(id: String, to name: String) async throws {
        try await collection.document(id).updateData(["name": name])
    }

    func delete(id: String) async throws {
        try await collection.document(id).delete()
    }
}
