@preconcurrency import FirebaseFirestore
import Foundation
import NostargiaKit

/// users/{uid} のプロフィールと、アカウント全体のデータ
final class FirestoreProfileRepository: ProfileRepository, @unchecked Sendable {
    static let defaultTagNames = ["休日", "誕生日", "アニバーサリー"]
    /// users/{uid} の下にあるサブコレクション（futureMessages は段階3で使う）
    static let subcollections = ["stars", "tags", "futureMessages"]

    private let document: DocumentReference
    private let now: @Sendable () -> Date

    init(uid: String, db: Firestore = .firestore(), now: @escaping @Sendable () -> Date = { Date() }) {
        document = db.collection("users").document(uid)
        self.now = now
    }

    func profile() async throws -> UserProfile? {
        let snapshot = try await document.getDocument()
        guard let data = snapshot.data(),
              let userName = data["userName"] as? String,
              let birthday = (data["birthday"] as? Timestamp)?.dateValue()
        else { return nil }
        return UserProfile(userName: userName, birthday: birthday)
    }

    func create(_ profile: UserProfile) async throws {
        let batch = document.firestore.batch()
        batch.setData([
            "userName": profile.userName,
            "birthday": Timestamp(date: profile.birthday),
            "createdAt": FieldValue.serverTimestamp(),
        ], forDocument: document)
        // 並び順を保つため、作成日時を 1 ミリ秒ずつずらす
        let base = now()
        for (index, name) in Self.defaultTagNames.enumerated() {
            batch.setData([
                "name": name,
                "createdAt": Timestamp(date: base.addingTimeInterval(Double(index) / 1000)),
            ], forDocument: document.collection("tags").document())
        }
        try await batch.commit()
    }

    func updateUserName(_ name: String) async throws {
        try await document.updateData(["userName": name])
    }

    func deleteAllData() async throws {
        for name in Self.subcollections {
            // キャッシュから読むとオフラインでも先へ進み、commit が通信の回復を待ち続けてしまうので、サーバーから読む
            let snapshot = try await document.collection(name).getDocuments(source: .server)
            // 1回のバッチは最大500件
            for chunk in stride(from: 0, to: snapshot.documents.count, by: 500) {
                let batch = document.firestore.batch()
                for item in snapshot.documents[chunk..<min(chunk + 500, snapshot.documents.count)] {
                    batch.deleteDocument(item.reference)
                }
                try await batch.commit()
            }
        }
        try await document.delete()
    }
}
