import Foundation

/// 星に付けたタグ。タグを削除しても表示できるように名前もコピーして持つ
public struct TagRef: Codable, Hashable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct Tag: Hashable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public let createdAt: Date

    public init(id: String, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public struct UserProfile: Hashable, Sendable {
    public var userName: String
    public var birthday: Date

    public init(userName: String, birthday: Date) {
        self.userName = userName
        self.birthday = birthday
    }
}

/// 保存前の星（ID と保存時刻はデータ層が付ける）
public struct StarDraft: Hashable, Sendable {
    public var position: StarPosition
    public var color: StarColor
    public var scale: Double
    public var random: Double
    /// 朝6時区切りの判定とカレンダー表示に使う日時（デバッグ用の日数ずらし込み）
    public var displayDate: Date
    public var mood: MoodValues
    public var emotion: String
    public var feedback: String
    public var totalScore: Double
    public var goodThings: [String]
    public var tag: TagRef?
    public var constellation: ConstellationAssignment?
    public var isTutorial: Bool

    public init(
        position: StarPosition, color: StarColor, scale: Double, random: Double, displayDate: Date,
        mood: MoodValues, emotion: String, feedback: String, totalScore: Double, goodThings: [String],
        tag: TagRef?, constellation: ConstellationAssignment?, isTutorial: Bool
    ) {
        self.position = position
        self.color = color
        self.scale = scale
        self.random = random
        self.displayDate = displayDate
        self.mood = mood
        self.emotion = emotion
        self.feedback = feedback
        self.totalScore = totalScore
        self.goodThings = goodThings
        self.tag = tag
        self.constellation = constellation
        self.isTutorial = isTutorial
    }
}

/// 保存済みの星
public struct Star: Hashable, Sendable, Identifiable {
    public let id: String
    /// サーバー時刻。オフラインで書いた直後は推定値
    public let createdAt: Date?
    public var position: StarPosition
    public var color: StarColor
    public var scale: Double
    public var random: Double
    public var displayDate: Date
    public var mood: MoodValues
    public var emotion: String
    public var feedback: String
    public var totalScore: Double
    public var goodThings: [String]
    public var tag: TagRef?
    public var constellation: ConstellationAssignment?
    public var isTutorial: Bool

    public init(id: String, createdAt: Date?, draft: StarDraft) {
        self.id = id
        self.createdAt = createdAt
        position = draft.position
        color = draft.color
        scale = draft.scale
        random = draft.random
        displayDate = draft.displayDate
        mood = draft.mood
        emotion = draft.emotion
        feedback = draft.feedback
        totalScore = draft.totalScore
        goodThings = draft.goodThings
        tag = draft.tag
        constellation = draft.constellation
        isTutorial = draft.isTutorial
    }

    public var draft: StarDraft {
        StarDraft(
            position: position, color: color, scale: scale, random: random, displayDate: displayDate,
            mood: mood, emotion: emotion, feedback: feedback, totalScore: totalScore, goodThings: goodThings,
            tag: tag, constellation: constellation, isTutorial: isTutorial
        )
    }
}
