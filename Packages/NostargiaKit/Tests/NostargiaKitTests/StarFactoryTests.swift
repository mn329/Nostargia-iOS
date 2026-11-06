import Foundation
import Testing
@testable import NostargiaKit

struct StarFactoryTests {
    @Test func ordinaryStarIsRandomlyPlaced() {
        let mood = MoodValues(emotional: 10, motivation: 20, social: 30, physical: 40, fulfillment: 50)
        // 位置で3回、scale で1回、random で1回
        var random = SequenceRandom([0.5, 0.5, 0.5, 0.2, 0.9])
        let star = StarFactory.make(mood: mood, existing: [], random: &random)
        #expect(star.constellation == nil)
        #expect(star.position == StarPosition(x: 0, y: 0, z: -10))
        #expect(star.color == StarAppearance.color(for: mood))
        #expect(abs(star.scale - StarAppearance.scale(for: mood, inConstellation: false, random: 0.2)) < 1e-12)
        #expect(star.random == 0.9)
    }

    @Test func happyStarJoinsConstellation() throws {
        let mood = MoodValues(all: 80)
        var random = SequenceRandom([0.5, 0.3, 0.7])
        let star = StarFactory.make(mood: mood, existing: [], random: &random)
        #expect(star.constellation == ConstellationAssignment(id: "andromeda", nodeIndex: 0))
        let andromeda = try #require(ConstellationCatalog.all.first)
        var same = SequenceRandom([0.5])
        #expect(star.position == StarPlacement.position(for: ConstellationAssignment(id: "andromeda", nodeIndex: 0), in: andromeda, random: &same))
        #expect(abs(star.scale - StarAppearance.scale(for: mood, inConstellation: true, random: 0.3)) < 1e-12)
        #expect(star.random == 0.7)
    }

    @Test func happyStarFallsBackToRandomWhenAllFull() {
        let existing = ConstellationCatalog.all.flatMap { c in
            (0..<c.starCount).map { i in
                ExistingStar(position: StarPosition(x: 0, y: 0, z: 0), constellation: ConstellationAssignment(id: c.id, nodeIndex: i))
            }
        }
        var random = SequenceRandom([0.9, 0.9, 0.5, 0.1, 0.4])
        let star = StarFactory.make(mood: MoodValues(all: 100), existing: existing, random: &random)
        #expect(star.constellation == nil)
        #expect(abs(star.position.x - 256) < 1e-9)
        #expect(abs(star.scale - StarAppearance.scale(for: MoodValues(all: 100), inConstellation: false, random: 0.1)) < 1e-12)
    }
}
