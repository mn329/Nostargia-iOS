import Foundation

/// 星の色（three.js の作業色空間 = リニア の値。Web版の t_stars.color と同じ）
public struct StarColor: Codable, Hashable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// three.js の `new THREE.Color(0xRRGGBB)` と同じく、sRGB の16進値をリニアに変換する
    public init(srgbHex hex: UInt32) {
        func linear(_ byte: UInt32) -> Double {
            let c = Double(byte) / 255
            return c < 0.04045 ? c * 0.0773993808 : pow(c * 0.9478672986 + 0.0521327014, 2.4)
        }
        self.init(r: linear((hex >> 16) & 0xFF), g: linear((hex >> 8) & 0xFF), b: linear(hex & 0xFF))
    }
}

/// 星の見た目（Web版 src/utils/starDataMaker.js の generateMoodColor と scale 計算の移植）
public enum StarAppearance {
    static let gold = StarColor(srgbHex: 0xFFD700)
    static let grey = StarColor(srgbHex: 0xA0A0A5)

    /// emotional: 黄、motivation: 赤、social: マゼンタ、physical: シアン、fulfillment: 緑 を重み付けで混ぜ、最大成分で正規化する
    public static func color(for mood: MoodValues) -> StarColor {
        if mood.all.allSatisfy({ $0 == 100 }) { return gold }
        if mood.all.allSatisfy({ $0 == 0 }) { return grey }

        let bases: [(r: Double, g: Double, b: Double)] = [(1, 1, 0), (1, 0, 0), (1, 0, 1), (0, 1, 1), (0, 1, 0)]
        let weights = mood.all.map { Double($0) / 100 }
        var r = 0.0
        var g = 0.0
        var b = 0.0
        for (base, w) in zip(bases, weights) {
            r += base.r * w
            g += base.g * w
            b += base.b * w
        }
        let maxComponent = max(r, g, b)
        if maxComponent == 0 { return grey }
        return StarColor(r: r / maxComponent, g: g / maxComponent, b: b / maxComponent)
    }

    /// random は 0..<1 の乱数（Web版の Math.random() に相当）
    public static func scale(for mood: MoodValues, inConstellation: Bool, random: Double) -> Double {
        let baseScale = inConstellation ? 2.5 : 2.0
        let fulfillmentBonus = Double(mood.fulfillment) / 100 * 2.0
        let physicalBonus = Double(mood.physical) / 100 * 1.5
        return baseScale + fulfillmentBonus + physicalBonus + random * 0.5
    }
}
