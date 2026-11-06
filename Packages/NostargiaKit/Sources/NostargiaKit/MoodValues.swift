import Foundation

/// 日記のスライダー5値（各0〜100）。キー名は Web版の mood_values と同じ。
public struct MoodValues: Codable, Hashable, Sendable {
    public var emotional: Int
    public var motivation: Int
    public var social: Int
    public var physical: Int
    public var fulfillment: Int

    public init(emotional: Int, motivation: Int, social: Int, physical: Int, fulfillment: Int) {
        self.emotional = emotional
        self.motivation = motivation
        self.social = social
        self.physical = physical
        self.fulfillment = fulfillment
    }

    public init(all value: Int) {
        self.init(emotional: value, motivation: value, social: value, physical: value, fulfillment: value)
    }

    /// スライダーの初期値
    public static let neutral = MoodValues(all: 50)

    public var all: [Int] { [emotional, motivation, social, physical, fulfillment] }

    public func allAtLeast(_ threshold: Int) -> Bool { all.allSatisfy { $0 >= threshold } }

    public func allBelow(_ threshold: Int) -> Bool { all.allSatisfy { $0 < threshold } }
}
