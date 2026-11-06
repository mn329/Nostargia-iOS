import Foundation

/// アプリの現在時刻。デバッグ用の日数ずらし（Web版の debugDayOffset）を反映する
public struct AppClock: Sendable {
    public var debugDayOffset: Int
    public let calendar: Calendar
    private let base: @Sendable () -> Date

    public init(debugDayOffset: Int = 0, calendar: Calendar = .current, base: @escaping @Sendable () -> Date = { Date() }) {
        self.debugDayOffset = debugDayOffset
        self.calendar = calendar
        self.base = base
    }

    public func now() -> Date {
        let date = base()
        guard debugDayOffset != 0 else { return date }
        return calendar.date(byAdding: .day, value: debugDayOffset, to: date)!
    }
}
