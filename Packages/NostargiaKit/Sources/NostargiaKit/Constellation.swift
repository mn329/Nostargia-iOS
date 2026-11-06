import Foundation

/// 星座データ（Web版 src/data/constellationData.js から生成した constellations.json）
public struct Constellation: Codable, Hashable, Sendable, Identifiable {
    /// 0〜1 に正規化された星の位置（y=0 が上端）
    public struct Node: Codable, Hashable, Sendable {
        public let x: Double
        public let y: Double
    }

    public let id: String
    public let name: String
    public let starCount: Int
    public let description: String
    public let features: String
    public let history: String
    public let starPositions: [Node]
    public let lines: [[Int]]
}

public enum ConstellationCatalog {
    /// Web版と同じ順番の9星座。割り当てはこの順で埋まっていく
    public static let all: [Constellation] = {
        guard let url = Bundle.module.url(forResource: "constellations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Constellation].self, from: data)
        else {
            fatalError("constellations.json を読み込めません。tools/golden/generate.mjs を実行してください")
        }
        return list
    }()
}
