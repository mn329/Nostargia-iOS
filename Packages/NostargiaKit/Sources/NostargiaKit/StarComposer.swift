import Foundation

/// 日記モーダルで入力された内容
public struct DiaryEntry: Hashable, Sendable {
    public static let maxGoodThings = 3

    public var mood: MoodValues
    public var goodThings: [String]
    public var tag: TagRef?
    public var isTutorial: Bool

    public init(mood: MoodValues, goodThings: [String], tag: TagRef?, isTutorial: Bool = false) {
        self.mood = mood
        self.goodThings = goodThings
        self.tag = tag
        self.isTutorial = isTutorial
    }

    /// 前後の空白を除き、空の行を捨て、最大3件にする
    public static func normalize(_ goodThings: [String]) -> [String] {
        Array(
            goodThings
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(maxGoodThings)
        )
    }

    public var normalizedGoodThings: [String] { Self.normalize(goodThings) }
}

/// 日記の入力から保存前の星を組み立てる（Web版 UI.jsx の handleSend で行っていた組み立て）
public enum StarComposer {
    /// letter が nil のとき（AI が使えなかったとき）は定型文の手紙を使う
    public static func draft(
        entry: DiaryEntry,
        existing: [Star],
        letter: String?,
        now: Date,
        catalog: [Constellation] = ConstellationCatalog.all,
        random: inout some RandomSource
    ) -> StarDraft {
        let goodThings = entry.normalizedGoodThings
        let analysis = MoodAnalyzer.analyze(entry.mood, goodThings: goodThings)
        let blueprint = StarFactory.make(
            mood: entry.mood,
            existing: existing.map { ExistingStar(position: $0.position, constellation: $0.constellation) },
            catalog: catalog,
            random: &random
        )
        return StarDraft(
            position: blueprint.position,
            color: blueprint.color,
            scale: blueprint.scale,
            random: blueprint.random,
            displayDate: now,
            mood: entry.mood,
            emotion: analysis.emotion,
            feedback: letter ?? analysis.fallbackFeedback,
            totalScore: analysis.totalScore,
            goodThings: goodThings,
            tag: entry.tag,
            constellation: blueprint.constellation,
            isTutorial: entry.isTutorial
        )
    }
}
