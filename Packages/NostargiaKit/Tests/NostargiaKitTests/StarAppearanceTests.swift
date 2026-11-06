import Foundation
import Testing
@testable import NostargiaKit

struct StarAppearanceTests {
    struct GoldenCase: Decodable {
        let mood: MoodValues
        let color: StarColor
    }

    @Test func colorMatchesWeb() throws {
        let cases = try Fixture.load("mood_color", as: [GoldenCase].self)
        #expect(cases.count == 454)
        for c in cases {
            let color = StarAppearance.color(for: c.mood)
            #expect(abs(color.r - c.color.r) < 1e-9, "\(c.mood)")
            #expect(abs(color.g - c.color.g) < 1e-9, "\(c.mood)")
            #expect(abs(color.b - c.color.b) < 1e-9, "\(c.mood)")
        }
    }

    @Test func goldWhenAllHundred() {
        let gold = StarAppearance.color(for: MoodValues(all: 100))
        #expect(gold.r == 1)
        #expect(abs(gold.g - 0.6795425) < 1e-6)
        #expect(gold.b == 0)
    }

    @Test func scaleFormula() {
        let mood = MoodValues(emotional: 0, motivation: 0, social: 0, physical: 40, fulfillment: 50)
        // 2.0 + 0.5*2.0 + 0.4*1.5 + 0.2*0.5
        #expect(abs(StarAppearance.scale(for: mood, inConstellation: false, random: 0.2) - 3.7) < 1e-12)
        // 星座の星は基準が 2.5
        #expect(abs(StarAppearance.scale(for: mood, inConstellation: true, random: 0) - 4.1) < 1e-12)
    }
}
