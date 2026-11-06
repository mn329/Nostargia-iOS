import Foundation

/// 星からの手紙を Gemini に頼むプロンプト（Web版 supabase/functions/analyze-diary/index.ts と同じ文面）
public enum LetterPrompt {
    /// goodThings は DiaryEntry.normalize 済みのものを渡す
    public static func build(mood: MoodValues, goodThings: [String]) -> String {
        let kibun = Double(mood.emotional)
        let energy = Double(mood.social + mood.physical) / 2
        let jiko = Double(mood.motivation + mood.fulfillment) / 2
        let emotion = MoodAnalyzer.emotion(mood)
        let totalScore = MoodAnalyzer.totalScore(mood)
        let goodThingsSection = goodThings.isEmpty
            ? ""
            : "\n【今日のいいこと】\n" + goodThings.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n") + "\n"
        let goodThingsLead = goodThings.isEmpty ? "" : "今日のいいことに触れつつ、"

        return """
        あなたは宇宙の星のように優しく見守る存在です。ユーザーが今日の気持ちを5つのスライダーで記録しました。

        【三軸感情分析システム】
        このシステムでは、5つのスライダー値を3つの軸に集約して感情を判定しています。

        ■ 三軸の定義:
        1. 気分軸（直感的な良い/悪い）: \(js(kibun))/100 → \(MoodAnalyzer.level(kibun))
        2. エネルギー軸（身体・心理の元気度）: \(js(energy))/100 → \(MoodAnalyzer.level(energy))
        3. 自己充足軸（自己満足・充足感）: \(js(jiko))/100 → \(MoodAnalyzer.level(jiko))

        ■ 各軸の区間: 低(0〜33) / 中(34〜66) / 高(67〜100)

        ■ 総合スコア: \(js(totalScore))/100
        （計算式: Q1×0.30 + Q2×0.25 + Q3×0.20 + Q4×0.10 + Q5×0.15）

        ■ 判定された感情タイプ: \(emotion)

        【元データ（5つのスライダー値）】
        - Q1 気分（今の気持ちは心地いい？）: \(mood.emotional)/100
        - Q2 自分らしさ（今日は自分らしく過ごせた？）: \(mood.motivation)/100
        - Q3 心の満たされ方: \(mood.social)/100
        - Q4 体の状態: \(mood.physical)/100
        - Q5 充実感: \(mood.fulfillment)/100
        \(goodThingsSection)
        上記の三軸分析結果と総合スコアを参考にして、この感情タイプ「\(emotion)」にふさわしい「星からの手紙」として、温かく共感的なメッセージを1-2文で生成してください。
        \(goodThingsLead)ユーザーの気持ちをそのまま受け止め、前向きになれる言葉をかけてください。夜空の星が語りかけるような優しいトーンで。

        注意事項:
        - 総合スコアが低い場合は無理にポジティブにせず、寄り添うメッセージにしてください
        - 三軸のバランス（例: 気分は良いがエネルギーが低いなど）を考慮してメッセージを作成してください
        - 感情タイプの名称をそのまま文中に使わないでください

        回答は以下のJSON形式のみで返してください（他の説明やマークダウンは不要です）：
        {
          "feedback": "フィードバックメッセージ"
        }
        """
    }

    /// JavaScript のテンプレート文字列と同じ数値の書き方（50.0 → "50"、50.5 → "50.5"）
    static func js(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}
