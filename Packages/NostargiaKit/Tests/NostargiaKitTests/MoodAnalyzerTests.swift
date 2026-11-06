import Foundation
import Testing
@testable import NostargiaKit

struct MoodAnalyzerTests {
    struct GoldenCase: Decodable {
        let mood: MoodValues
        let goodThings: [String]
        let emotion: String
        let feedback: String
        let totalScore: Double
    }

    @Test func matchesWebFallbackAnalysis() throws {
        let cases = try Fixture.load("mood_analysis", as: [GoldenCase].self)
        #expect(cases.count == 454)
        for c in cases {
            let result = MoodAnalyzer.analyze(c.mood, goodThings: c.goodThings)
            #expect(result.emotion == c.emotion, "\(c.mood)")
            #expect(result.fallbackFeedback == c.feedback, "\(c.mood) \(c.goodThings)")
            #expect(abs(result.totalScore - c.totalScore) < 1e-9, "\(c.mood)")
        }
    }

    @Test func blankGoodThingsAreIgnored() {
        let result = MoodAnalyzer.analyze(.neutral, goodThings: ["  ", "\u{3000}", ""])
        #expect(!result.fallbackFeedback.hasPrefix("「"))
    }

    @Test func boundaryLevels() {
        #expect(MoodAnalyzer.emotion(MoodValues(all: 33)) == "消耗・虚無")
        #expect(MoodAnalyzer.emotion(MoodValues(all: 34)) == "普通・平穏")
        #expect(MoodAnalyzer.emotion(MoodValues(all: 67)) == "うれしい・充実・幸福")
    }
}
