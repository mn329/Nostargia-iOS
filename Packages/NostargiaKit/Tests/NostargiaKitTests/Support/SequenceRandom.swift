@testable import NostargiaKit

/// 決めた値を順番に（最後まで行ったら先頭から）返す乱数
struct SequenceRandom: RandomSource {
    private let values: [Double]
    private var index = 0

    init(_ values: [Double]) {
        self.values = values
    }

    mutating func next() -> Double {
        defer { index += 1 }
        return values[index % values.count]
    }
}
