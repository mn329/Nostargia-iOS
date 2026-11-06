import Foundation

/// 配置済みの星（位置の衝突判定と星座の空き確認に使う）
public struct ExistingStar: Sendable {
    public let position: StarPosition
    public let constellation: ConstellationAssignment?

    public init(position: StarPosition, constellation: ConstellationAssignment?) {
        self.position = position
        self.constellation = constellation
    }
}

/// 保存前の新しい星の見た目と位置
public struct StarBlueprint: Equatable, Sendable {
    public let position: StarPosition
    public let color: StarColor
    public let scale: Double
    /// 瞬きなどの個体差に使う 0..<1 の値（Web版 t_stars.random）
    public let random: Double
    public let constellation: ConstellationAssignment?
}

/// Web版 starDataMaker の移植。日付や ID は保存時にデータ層で付ける
public enum StarFactory {
    public static func make(
        mood: MoodValues,
        existing: [ExistingStar],
        catalog: [Constellation] = ConstellationCatalog.all,
        random: inout some RandomSource
    ) -> StarBlueprint {
        let assignment = ConstellationAssigner.assign(
            mood: mood,
            existing: existing.compactMap(\.constellation),
            catalog: catalog
        )

        let position: StarPosition
        if let assignment, let constellation = catalog.first(where: { $0.id == assignment.id }) {
            position = StarPlacement.position(for: assignment, in: constellation, random: &random)
        } else {
            let constellationStars = existing.filter { $0.constellation != nil }.map(\.position)
            position = StarPlacement.randomPosition(avoiding: constellationStars, random: &random)
        }

        return StarBlueprint(
            position: position,
            color: StarAppearance.color(for: mood),
            scale: StarAppearance.scale(for: mood, inConstellation: assignment != nil, random: random.next()),
            random: random.next(),
            constellation: assignment
        )
    }
}
