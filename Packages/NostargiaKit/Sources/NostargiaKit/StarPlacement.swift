import Foundation

public struct StarPosition: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// 星の位置（Web版 src/utils/starDataMaker.js の移植）。星空の範囲は X ±320、Y ±160
public enum StarPlacement {
    static let boxSize = 60.0
    static let minX = -320 + boxSize / 2 + 10
    static let maxX = 320 - boxSize / 2 - 10
    static let minY = -160 + boxSize / 2 + 10
    static let maxY = 160 - boxSize / 2 - 10

    /// Web版 hashCode と同じ（UTF-16 単位で 32bit 整数演算、最後に絶対値）
    public static func hashCode(_ string: String) -> Int64 {
        var hash: Int32 = 0
        for unit in string.utf16 {
            hash = (hash &<< 5) &- hash &+ Int32(unit)
        }
        return abs(Int64(hash))
    }

    /// 星座の中心。z は星座全体の基準の奥行き
    public static func constellationCenter(id: String) -> StarPosition {
        let hash = hashCode(id)
        let prngX = Double(hash % 100) / 100
        let prngY = Double((hash * 13) % 100) / 100
        let prngZ = Double((hash * 17) % 100) / 100
        return StarPosition(
            x: minX + prngX * (maxX - minX),
            y: minY + prngY * (maxY - minY),
            z: -10 + prngZ * 15
        )
    }

    public static func position(
        for assignment: ConstellationAssignment,
        in constellation: Constellation,
        random: inout some RandomSource
    ) -> StarPosition {
        let center = constellationCenter(id: constellation.id)
        let node = constellation.starPositions[assignment.nodeIndex]
        let localX = (node.x - 0.5) * boxSize
        // 星座データは y=0 が上端、星空は y が大きいほど上なので反転する
        let localY = (0.5 - node.y) * boxSize
        return StarPosition(
            x: center.x + localX,
            y: center.y + localY,
            z: center.z + (random.next() - 0.5) * 2
        )
    }

    /// 星座の星から半径5以内を避けてランダムに置く。50回試してもだめなら最後の候補を使う
    public static func randomPosition(
        avoiding constellationStars: [StarPosition],
        random: inout some RandomSource
    ) -> StarPosition {
        var candidate = StarPosition(x: 0, y: 0, z: 0)
        for _ in 0..<50 {
            let x = (random.next() - 0.5) * 640
            let y = (random.next() - 0.5) * 320
            let z = -10 + (random.next() - 0.5) * 15
            candidate = StarPosition(x: x, y: y, z: z)
            let collides = constellationStars.contains { p in
                let dx = p.x - x
                let dy = p.y - y
                let dz = p.z - z
                return dx * dx + dy * dy + dz * dz < 25
            }
            if !collides { break }
        }
        return candidate
    }
}
