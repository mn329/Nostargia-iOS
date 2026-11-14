import Foundation
import Testing
@testable import NostargiaKit

struct LetterPromptTests {
    struct GoldenCase: Decodable {
        let mood: MoodValues
        let goodThings: [String]
        let prompt: String
    }

    @Test func matchesWebEdgeFunction() throws {
        let cases = try Fixture.load("letter_prompt", as: [GoldenCase].self)
        #expect(cases.count == 60)
        for c in cases {
            #expect(LetterPrompt.build(mood: c.mood, goodThings: DiaryEntry.normalize(c.goodThings)) == c.prompt, "\(c.mood) \(c.goodThings)")
        }
    }

    @Test func halfPointsAreWrittenLikeJavaScript() {
        let prompt = LetterPrompt.build(mood: MoodValues(emotional: 50, motivation: 50, social: 50, physical: 51, fulfillment: 50), goodThings: [])
        #expect(prompt.contains("エネルギー軸（身体・心理の元気度）: 50.5/100"))
        #expect(prompt.contains("気分軸（直感的な良い/悪い）: 50/100"))
    }
}
