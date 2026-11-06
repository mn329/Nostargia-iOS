import Foundation
import Testing
@testable import NostargiaKit

struct ConstellationAssignerTests {
    let happy = MoodValues(all: 50)

    @Test func catalogHasNineInWebOrder() {
        let ids = ConstellationCatalog.all.map(\.id)
        #expect(ids == ["andromeda", "monoceros", "sagittarius", "delphinus", "indus", "pisces", "lepus", "bootes", "hydra"])
        #expect(ConstellationCatalog.all.allSatisfy { $0.starPositions.count == $0.starCount })
    }

    @Test func notCandidateWhenAnySliderBelowFifty() {
        var mood = happy
        mood.physical = 49
        #expect(ConstellationAssigner.assign(mood: mood, existing: []) == nil)
    }

    @Test func firstFreeNodeOfFirstOpenConstellation() {
        let existing = [
            ConstellationAssignment(id: "andromeda", nodeIndex: 0),
            ConstellationAssignment(id: "andromeda", nodeIndex: 2),
        ]
        #expect(ConstellationAssigner.assign(mood: happy, existing: existing) == ConstellationAssignment(id: "andromeda", nodeIndex: 1))
    }

    @Test func movesToNextWhenFull() {
        let existing = (0..<11).map { ConstellationAssignment(id: "andromeda", nodeIndex: $0) }
        #expect(ConstellationAssigner.assign(mood: happy, existing: existing) == ConstellationAssignment(id: "monoceros", nodeIndex: 0))
    }

    @Test func nilWhenEverythingIsFull() {
        let existing = ConstellationCatalog.all.flatMap { c in
            (0..<c.starCount).map { ConstellationAssignment(id: c.id, nodeIndex: $0) }
        }
        #expect(ConstellationAssigner.assign(mood: happy, existing: existing) == nil)
    }

    @Test func corruptedIndicesDoNotCrash() {
        // 範囲外の nodeIndex が混ざっていても、空きが無い星座は飛ばす
        let existing = (0..<10).map { ConstellationAssignment(id: "andromeda", nodeIndex: $0) }
            + [ConstellationAssignment(id: "andromeda", nodeIndex: 99)]
            + (0..<10).map { ConstellationAssignment(id: "andromeda", nodeIndex: $0) }
        let result = ConstellationAssigner.assign(mood: happy, existing: existing)
        #expect(result == ConstellationAssignment(id: "andromeda", nodeIndex: 10))

        let broken = (1..<11).map { ConstellationAssignment(id: "andromeda", nodeIndex: $0) }
            + [ConstellationAssignment(id: "andromeda", nodeIndex: 0)]
            + [ConstellationAssignment(id: "andromeda", nodeIndex: -1)]
        #expect(ConstellationAssigner.assign(mood: happy, existing: broken) == ConstellationAssignment(id: "monoceros", nodeIndex: 0))
    }
}
