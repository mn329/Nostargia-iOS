import Foundation

public struct ConstellationAssignment: Codable, Hashable, Sendable {
    public let id: String
    public let nodeIndex: Int

    public init(id: String, nodeIndex: Int) {
        self.id = id
        self.nodeIndex = nodeIndex
    }
}

/// 星座ノードの割り当て（Web版 src/utils/starDataMaker.js の星座判定の移植）
public enum ConstellationAssigner {
    /// 全スライダーが 50 以上なら、カタログの順に見て最初に空きがある星座の、最小の空きノードを返す
    public static func assign(
        mood: MoodValues,
        existing: [ConstellationAssignment],
        catalog: [Constellation] = ConstellationCatalog.all
    ) -> ConstellationAssignment? {
        guard mood.allAtLeast(50) else { return nil }

        for constellation in catalog {
            let taken = Set(existing.filter { $0.id == constellation.id }.map(\.nodeIndex))
            // Web版は空きが見つからないと nodeIndex = -1 で壊れた星を作るため、ここでは次の星座へ進む
            if let free = (0..<constellation.starCount).first(where: { !taken.contains($0) }) {
                return ConstellationAssignment(id: constellation.id, nodeIndex: free)
            }
        }
        return nil
    }
}
