import Foundation
import Testing
@testable import NostargiaKit

struct StarPlacementTests {
    struct GoldenHash: Decodable {
        let input: String
        let hash: Int64
        let centerX: Double
        let centerY: Double
        let baseZ: Double
    }

    @Test func hashAndCenterMatchWeb() throws {
        let cases = try Fixture.load("constellation_hash", as: [GoldenHash].self)
        #expect(cases.count == 13)
        for c in cases {
            #expect(StarPlacement.hashCode(c.input) == c.hash, "\(c.input)")
            let center = StarPlacement.constellationCenter(id: c.input)
            #expect(abs(center.x - c.centerX) < 1e-9, "\(c.input)")
            #expect(abs(center.y - c.centerY) < 1e-9, "\(c.input)")
            #expect(abs(center.z - c.baseZ) < 1e-9, "\(c.input)")
        }
    }

    @Test func constellationNodePosition() throws {
        let andromeda = try #require(ConstellationCatalog.all.first { $0.id == "andromeda" })
        let center = StarPlacement.constellationCenter(id: "andromeda")
        var random = SequenceRandom([0.5])
        let p = StarPlacement.position(for: ConstellationAssignment(id: "andromeda", nodeIndex: 0), in: andromeda, random: &random)
        // node 0 = (0.12, 0.5)。y は反転、z の揺らぎは乱数 0.5 で 0
        #expect(abs(p.x - (center.x + (0.12 - 0.5) * 60)) < 1e-9)
        #expect(abs(p.y - (center.y + (0.5 - 0.5) * 60)) < 1e-9)
        #expect(abs(p.z - center.z) < 1e-9)
    }

    @Test func randomPositionUsesWebRanges() {
        var random = SequenceRandom([0.0, 1.0, 0.5])
        let p = StarPlacement.randomPosition(avoiding: [], random: &random)
        #expect(p == StarPosition(x: -320, y: 160, z: -10))
    }

    @Test func randomPositionRetriesNearConstellationStars() {
        // 1回目 (0,0,-10) は星座の星に近すぎるので、2回目 (64,32,-10) を使う
        var random = SequenceRandom([0.5, 0.5, 0.5, 0.6, 0.6, 0.5])
        let p = StarPlacement.randomPosition(avoiding: [StarPosition(x: 1, y: 1, z: -10)], random: &random)
        #expect(abs(p.x - 64) < 1e-9)
        #expect(abs(p.y - 32) < 1e-9)
    }

    @Test func randomPositionGivesUpAfterFiftyTries() {
        // ずっと近すぎる場合も、50回で諦めて最後の候補を返す
        var random = SequenceRandom([0.5])
        let p = StarPlacement.randomPosition(avoiding: [StarPosition(x: 0, y: 0, z: -10)], random: &random)
        #expect(p == StarPosition(x: 0, y: 0, z: -10))
    }
}
