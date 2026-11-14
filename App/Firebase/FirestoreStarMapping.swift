@preconcurrency import FirebaseFirestore
import Foundation
import NostargiaKit

/// Star と Firestore のドキュメント（spec 4章のフィールド）の変換
enum FirestoreStarMapping {
    static func data(from draft: StarDraft) -> [String: Any] {
        [
            "position": ["x": draft.position.x, "y": draft.position.y, "z": draft.position.z],
            "color": ["r": draft.color.r, "g": draft.color.g, "b": draft.color.b],
            "scale": draft.scale,
            "random": draft.random,
            "createdAt": FieldValue.serverTimestamp(),
            "displayDate": Timestamp(date: draft.displayDate),
            "mood": [
                "emotional": draft.mood.emotional,
                "motivation": draft.mood.motivation,
                "social": draft.mood.social,
                "physical": draft.mood.physical,
                "fulfillment": draft.mood.fulfillment,
            ],
            "emotion": draft.emotion,
            "feedback": draft.feedback,
            "totalScore": draft.totalScore,
            "goodThings": draft.goodThings,
            "tag": draft.tag.map { ["id": $0.id, "name": $0.name] } ?? NSNull(),
            "constellation": draft.constellation.map { ["id": $0.id, "nodeIndex": $0.nodeIndex] } ?? NSNull(),
            "isTutorial": draft.isTutorial,
        ]
    }

    /// 必須の項目が欠けている・型が違うドキュメントは nil
    static func star(id: String, data: [String: Any]) -> Star? {
        guard let position = data["position"] as? [String: Any],
              let x = position["x"] as? Double, let y = position["y"] as? Double, let z = position["z"] as? Double,
              let color = data["color"] as? [String: Any],
              let r = color["r"] as? Double, let g = color["g"] as? Double, let b = color["b"] as? Double,
              let scale = data["scale"] as? Double,
              let random = data["random"] as? Double,
              let displayDate = (data["displayDate"] as? Timestamp)?.dateValue(),
              let mood = data["mood"] as? [String: Any],
              let emotional = mood["emotional"] as? Int, let motivation = mood["motivation"] as? Int,
              let social = mood["social"] as? Int, let physical = mood["physical"] as? Int,
              let fulfillment = mood["fulfillment"] as? Int,
              let emotion = data["emotion"] as? String,
              let feedback = data["feedback"] as? String,
              let totalScore = data["totalScore"] as? Double
        else { return nil }

        let tag = (data["tag"] as? [String: Any]).flatMap { dict -> TagRef? in
            guard let id = dict["id"] as? String, let name = dict["name"] as? String else { return nil }
            return TagRef(id: id, name: name)
        }
        let constellation = (data["constellation"] as? [String: Any]).flatMap { dict -> ConstellationAssignment? in
            guard let id = dict["id"] as? String, let nodeIndex = dict["nodeIndex"] as? Int else { return nil }
            return ConstellationAssignment(id: id, nodeIndex: nodeIndex)
        }

        let draft = StarDraft(
            position: StarPosition(x: x, y: y, z: z),
            color: StarColor(r: r, g: g, b: b),
            scale: scale,
            random: random,
            displayDate: displayDate,
            mood: MoodValues(emotional: emotional, motivation: motivation, social: social, physical: physical, fulfillment: fulfillment),
            emotion: emotion,
            feedback: feedback,
            totalScore: totalScore,
            goodThings: data["goodThings"] as? [String] ?? [],
            tag: tag,
            constellation: constellation,
            isTutorial: data["isTutorial"] as? Bool ?? false
        )
        return Star(id: id, createdAt: (data["createdAt"] as? Timestamp)?.dateValue(), draft: draft)
    }
}
