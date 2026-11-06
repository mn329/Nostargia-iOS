import Foundation
import Testing

/// tools/golden/generate.mjs が書き出した JSON を読み込む
enum Fixture {
    static func load<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
