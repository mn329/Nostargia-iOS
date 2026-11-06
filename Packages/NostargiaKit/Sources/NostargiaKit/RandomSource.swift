import Foundation

/// 0..<1 の乱数。テストで結果を固定できるように差し替え可能にしている
public protocol RandomSource {
    mutating func next() -> Double
}

public struct SystemRandomSource: RandomSource {
    public init() {}

    public mutating func next() -> Double {
        Double.random(in: 0..<1)
    }
}
