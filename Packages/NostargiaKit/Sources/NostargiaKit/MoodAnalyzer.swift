import Foundation

public struct MoodAnalysis: Equatable, Sendable {
    /// 27通りの感情タイプ
    public let emotion: String
    public let totalScore: Double
    /// AI の手紙が使えないときの定型文
    public let fallbackFeedback: String
}

/// 三軸感情分析（Web版 src/utils/fallbackAnalysis.js の移植）
/// - 気分 = emotional
/// - エネルギー = (social + physical) / 2
/// - 自己充足 = (motivation + fulfillment) / 2
public enum MoodAnalyzer {
    public static func analyze(_ mood: MoodValues, goodThings: [String]) -> MoodAnalysis {
        let emotion = emotion(mood)
        let base = fallbackMessages[emotion] ?? fallbackMessages["普通・平穏"]!
        let items = goodThings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let feedback = items.isEmpty ? base : "「\(items.joined(separator: "、"))」いいですね。\(base)"
        return MoodAnalysis(emotion: emotion, totalScore: totalScore(mood), fallbackFeedback: feedback)
    }

    /// 総合スコア = Q1×0.30 + Q2×0.25 + Q3×0.20 + Q4×0.10 + Q5×0.15（小数第1位で四捨五入）
    public static func totalScore(_ mood: MoodValues) -> Double {
        let raw = Double(mood.emotional) * 0.30
            + Double(mood.motivation) * 0.25
            + Double(mood.social) * 0.20
            + Double(mood.physical) * 0.10
            + Double(mood.fulfillment) * 0.15
        return (raw * 10).rounded(.toNearestOrAwayFromZero) / 10
    }

    public static func emotion(_ mood: MoodValues) -> String {
        let kibun = Double(mood.emotional)
        let energy = Double(mood.social + mood.physical) / 2
        let jiko = Double(mood.motivation + mood.fulfillment) / 2
        let key = "\(level(kibun))_\(level(energy))_\(level(jiko))"
        return emotionTypes[key] ?? "普通・平穏"
    }

    /// 0〜33: 低、34〜66: 中、67〜100: 高
    static func level(_ value: Double) -> String {
        if value <= 33 { return "低" }
        if value <= 66 { return "中" }
        return "高"
    }

    static let emotionTypes: [String: String] = [
        "高_高_高": "うれしい・充実・幸福",
        "高_高_中": "満足・安定",
        "高_高_低": "元気だが物足りない",
        "高_中_高": "穏やか・安心",
        "高_中_中": "まずまず・平穏",
        "高_中_低": "気分は良いが空虚",
        "高_低_高": "リラックス・静穏",
        "高_低_中": "のんびり・ゆったり",
        "高_低_低": "気分は良いが無気力",
        "中_高_高": "やる気はあるが不安定",
        "中_高_中": "活動的だが迷い",
        "中_高_低": "空回り・焦り",
        "中_中_高": "静かな充足",
        "中_中_中": "普通・平穏",
        "中_中_低": "なんとなく不満",
        "中_低_高": "疲れているが満足",
        "中_低_中": "無気力・ぼんやり",
        "中_低_低": "停滞・モヤモヤ",
        "低_高_高": "イライラ・怒り",
        "低_高_中": "焦燥・不満",
        "低_高_低": "苛立ち・暴走",
        "低_中_高": "切なさ・寂しさ",
        "低_中_中": "落ち込み・悲しみ",
        "低_中_低": "憂鬱・自己嫌悪",
        "低_低_高": "燃え尽き・喪失感",
        "低_低_中": "疲弊・無力感",
        "低_低_低": "消耗・虚無",
    ]

    static let fallbackMessages: [String: String] = [
        "うれしい・充実・幸福": "今日はとても充実した一日でしたね。その輝きを忘れずに、明日もいい一日になりますように。",
        "満足・安定": "しっかりとした一日を過ごせましたね。その安定感があなたの強さです。",
        "元気だが物足りない": "元気いっぱいなのに、どこか満たされない気持ちがあるのかもしれません。新しい挑戦が良い刺激になるかも。",
        "穏やか・安心": "穏やかな気持ちで過ごせているのは素敵です。そのままのペースで大丈夫ですよ。",
        "まずまず・平穏": "特別ではなくても、穏やかに過ごせた今日は素敵な一日です。",
        "気分は良いが空虚": "気持ちは前向きなのに、心にぽっかり穴が空いたような感覚…。小さなことでも自分を満たしてあげてくださいね。",
        "リラックス・静穏": "ゆったりと心が落ち着いている時間、大切にしてくださいね。",
        "のんびり・ゆったり": "のんびり過ごせる日もあっていいですよね。自分のペースで大丈夫。",
        "気分は良いが無気力": "気持ちは悪くないのに体が動かない…そんな日もありますよ。ゆっくり休んでくださいね。",
        "やる気はあるが不安定": "エネルギーはあるのに気持ちが揺れている…そんな時は深呼吸して、一つずつ進めていきましょう。",
        "活動的だが迷い": "動けているのに方向が定まらない感じ、もどかしいですよね。焦らなくても答えは見つかります。",
        "空回り・焦り": "頑張っているのに空回りしている感覚、辛いですよね。少し立ち止まって休むのも前進です。",
        "静かな充足": "派手さはなくても、心の中に静かな満足感がある。それはとても豊かなことです。",
        "普通・平穏": "特別な日でなくても、今日一日を過ごせたこと自体が素敵なこと。お疲れさまでした。",
        "なんとなく不満": "はっきりしないモヤモヤ、言葉にしにくいですよね。自分の気持ちに耳を傾けてみてください。",
        "疲れているが満足": "体は疲れていても心は満たされている…そんな充実した疲労感は素敵です。ゆっくり休んでくださいね。",
        "無気力・ぼんやり": "ぼんやりする日もあります。無理せず、ただ流れに身を任せるのも悪くないですよ。",
        "停滞・モヤモヤ": "何もかもが止まっているように感じる時もあります。でも、止まっている時間も必要な時間です。",
        "イライラ・怒り": "イライラする気持ち、我慢しなくていいですよ。怒りはあなたが何かを大切にしている証拠です。",
        "焦燥・不満": "焦る気持ちと不満が重なると辛いですよね。少しだけ深呼吸して、今の自分を認めてあげてください。",
        "苛立ち・暴走": "気持ちが収まらない時は、無理に抑えなくても大丈夫。安全な方法で発散してくださいね。",
        "切なさ・寂しさ": "切ない気持ちは、あなたが誰かや何かを大切に思っている証。その優しさを忘れないでください。",
        "落ち込み・悲しみ": "少し辛い気持ちなのかもしれません。大丈夫、いつか必ず前に進めます。今日はゆっくり過ごしてください。",
        "憂鬱・自己嫌悪": "自分を責めてしまう時もありますよね。でも、あなたはそのままで十分頑張っています。",
        "燃え尽き・喪失感": "頑張りすぎた後の空っぽ感、辛いですよね。何もしない時間も回復には必要です。",
        "疲弊・無力感": "心も体もお疲れですね。無理しなくていいですよ。休むことも大切な仕事です。",
        "消耗・虚無": "今はとても辛い時期かもしれません。でも、この夜空のように、暗闇の中にも必ず光はあります。",
    ]
}
