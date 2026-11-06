import Foundation
import Testing
@testable import NostargiaKit

struct MoodValuesTests {
    @Test func neutralIsAllFifty() {
        #expect(MoodValues.neutral.all == [50, 50, 50, 50, 50])
    }

    @Test func thresholds() {
        let mood = MoodValues(emotional: 50, motivation: 60, social: 70, physical: 80, fulfillment: 90)
        #expect(mood.allAtLeast(50))
        #expect(!mood.allAtLeast(51))
        #expect(MoodValues(all: 24).allBelow(25))
        #expect(!MoodValues(all: 25).allBelow(25))
    }

    @Test func decodesWebKeys() throws {
        let json = #"{"emotional":1,"motivation":2,"social":3,"physical":4,"fulfillment":5}"#
        let mood = try JSONDecoder().decode(MoodValues.self, from: Data(json.utf8))
        #expect(mood.all == [1, 2, 3, 4, 5])
    }
}
