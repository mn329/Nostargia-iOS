import Foundation
import Testing
@testable import NostargiaKit

struct LetterServiceTests {
    struct FixedGenerator: LetterGenerating {
        let text: String
        func generate(prompt: String) async throws -> String { text }
    }

    struct FailingGenerator: LetterGenerating {
        struct Boom: Error {}
        func generate(prompt: String) async throws -> String { throw Boom() }
    }

    /// キャンセルにも応じず、ずっと返事をしない AI
    struct HangingGenerator: LetterGenerating {
        func generate(prompt: String) async throws -> String {
            try? await Task.sleep(for: .seconds(30))
            try? await Task.sleep(for: .seconds(30))
            return #"{"feedback":"遅すぎる返事"}"#
        }
    }

    actor PromptRecorder: LetterGenerating {
        private(set) var prompts: [String] = []
        func generate(prompt: String) async throws -> String {
            prompts.append(prompt)
            return #"{"feedback":"ok"}"#
        }
    }

    let entry = DiaryEntry(mood: MoodValues(all: 70), goodThings: [" 散歩 ", "", "a", "b", "c"], tag: nil)

    @Test func parsesPlainAndFencedJSON() {
        #expect(LetterResponse.feedback(from: #"{"feedback":"きれいな夜ですね。"}"#) == "きれいな夜ですね。")
        #expect(LetterResponse.feedback(from: "```json\n{\"feedback\": \" 星が見ています。 \"}\n```") == "星が見ています。")
    }

    @Test func rejectsBrokenResponses() {
        #expect(LetterResponse.feedback(from: "こんばんは") == nil)
        #expect(LetterResponse.feedback(from: #"{"feedback":"   "}"#) == nil)
        #expect(LetterResponse.feedback(from: #"{"message":"x"}"#) == nil)
    }

    @Test func returnsLetter() async {
        let service = LetterService(generator: FixedGenerator(text: #"{"feedback":"おつかれさま。"}"#))
        #expect(await service.letter(for: entry) == "おつかれさま。")
    }

    @Test func nilWhenGeneratorFails() async {
        #expect(await LetterService(generator: FailingGenerator()).letter(for: entry) == nil)
        #expect(await LetterService(generator: FixedGenerator(text: "JSONではない")).letter(for: entry) == nil)
    }

    @Test func nilAfterTimeoutEvenIfGeneratorHangs() async {
        let service = LetterService(generator: HangingGenerator(), timeout: .milliseconds(200))
        let clock = ContinuousClock()
        let start = clock.now
        let letter = await service.letter(for: entry)
        #expect(letter == nil)
        #expect(clock.now - start < .seconds(2))
    }

    @Test func sendsNormalizedPrompt() async {
        let recorder = PromptRecorder()
        _ = await LetterService(generator: recorder).letter(for: entry)
        let prompts = await recorder.prompts
        #expect(prompts == [LetterPrompt.build(mood: MoodValues(all: 70), goodThings: ["散歩", "a", "b"])])
    }
}
