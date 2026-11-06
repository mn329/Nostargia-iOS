import Foundation

/// 星からの手紙を作る AI。プロンプトを受け取り、生の返事（JSON のはず）を返す
public protocol LetterGenerating: Sendable {
    func generate(prompt: String) async throws -> String
}

/// AI の返事から手紙の本文を取り出す（Web版 analyze-diary と同じくコードブロックの記号を取り除く）
public enum LetterResponse {
    private struct Body: Decodable {
        let feedback: String
    }

    public static func feedback(from text: String) -> String? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let body = try? JSONDecoder().decode(Body.self, from: data)
        else { return nil }
        let feedback = body.feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        return feedback.isEmpty ? nil : feedback
    }
}

/// 手紙の生成。失敗・タイムアウト・壊れた返事のときは nil を返し、呼び出し側は定型文を使う
public struct LetterService: Sendable {
    private let generator: any LetterGenerating
    private let timeout: Duration

    public init(generator: any LetterGenerating, timeout: Duration = .seconds(10)) {
        self.generator = generator
        self.timeout = timeout
    }

    public func letter(for entry: DiaryEntry) async -> String? {
        let prompt = LetterPrompt.build(mood: entry.mood, goodThings: entry.normalizedGoodThings)
        guard let text = await firstOf(generate: prompt) else { return nil }
        return LetterResponse.feedback(from: text)
    }

    /// AI の返事とタイムアウトのうち先に来た方を返す。AI がキャンセルに応じなくても待たない
    private func firstOf(generate prompt: String) async -> String? {
        let generator = self.generator
        let timeout = self.timeout
        let once = Once()
        return await withCheckedContinuation { continuation in
            let work = Task {
                let text = try? await generator.generate(prompt: prompt)
                if await once.claim() { continuation.resume(returning: text) }
            }
            Task {
                try? await Task.sleep(for: timeout)
                if await once.claim() {
                    work.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

/// 一度だけ true を返す
private actor Once {
    private var claimed = false

    func claim() -> Bool {
        if claimed { return false }
        claimed = true
        return true
    }
}
