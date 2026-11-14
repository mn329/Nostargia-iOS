import Foundation
import XCTest

/// エミュレーター結合テストの共通部品。アプリ（ホスト）は起動時にエミュレーター向けに Firebase を初期化している
enum EmulatorSupport {
    static let password = "password123"

    /// テストごとに別のユーザーを作るためのメールアドレス
    static func freshEmail() -> String {
        "user-\(UUID().uuidString.prefix(8).lowercased())@example.com"
    }

    enum Failure: Error {
        case timeout
        case streamEnded
    }

    /// 条件を満たす値が流れてくるまで待つ
    static func firstValue<T: Sendable>(
        of stream: AsyncThrowingStream<T, Error>,
        timeout: Duration = .seconds(10),
        where predicate: @escaping @Sendable (T) -> Bool
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                for try await value in stream where predicate(value) {
                    return value
                }
                throw Failure.streamEnded
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw Failure.timeout
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    enum Outcome: Equatable, Sendable {
        case succeeded
        case failed
        case timedOut
    }

    /// 処理がキャンセルに応じなくても、時間切れになったらそこで結果を返す
    static func outcome(within timeout: Duration, _ body: @escaping @Sendable () async throws -> Void) async -> Outcome {
        let gate = Gate()
        return await withCheckedContinuation { continuation in
            Task {
                let result: Outcome
                do {
                    try await body()
                    result = .succeeded
                } catch {
                    result = .failed
                }
                if await gate.open() { continuation.resume(returning: result) }
            }
            Task {
                try? await Task.sleep(for: timeout)
                if await gate.open() { continuation.resume(returning: .timedOut) }
            }
        }
    }

    private actor Gate {
        private var opened = false

        func open() -> Bool {
            if opened { return false }
            opened = true
            return true
        }
    }
}
