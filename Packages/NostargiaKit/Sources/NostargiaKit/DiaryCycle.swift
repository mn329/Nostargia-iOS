import Foundation

/// 日記の周期とクールダウン（Web版 src/utils/appTime.js の移植）
/// 毎日 6:00 から翌日 6:00 までを1周期とし、1周期に書ける日記は1回
public struct DiaryCycle: Sendable {
    public static let resetHour = 6

    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// 6:00 より前なら前日の 6:00、以降なら当日の 6:00
    public func start(containing date: Date) -> Date {
        var day = calendar.startOfDay(for: date)
        if calendar.component(.hour, from: date) < Self.resetHour {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return calendar.date(bySettingHour: Self.resetHour, minute: 0, second: 0, of: day)!
    }

    /// 次の 6:00
    public func end(containing date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: start(containing: date))!
    }

    public func isCooldownActive(starDates: [Date], now: Date) -> Bool {
        guard let latest = latestPastStar(starDates, now: now) else { return false }
        return latest >= start(containing: now)
    }

    /// 0 = 書いた直後、1 = 書ける状態
    public func cooldownProgress(starDates: [Date], now: Date) -> Double {
        guard let latest = latestPastStar(starDates, now: now) else { return 1 }
        let cycleStart = start(containing: now)
        if latest < cycleStart { return 1 }
        let total = end(containing: now).timeIntervalSince(cycleStart)
        let elapsed = now.timeIntervalSince(cycleStart)
        return min(1, max(0, elapsed / total))
    }

    public func cooldownRemaining(now: Date) -> TimeInterval {
        max(0, end(containing: now).timeIntervalSince(now))
    }

    /// "7h 05m" の形式（分は切り上げ）
    public func cooldownText(now: Date) -> String {
        let totalMinutes = Int((cooldownRemaining(now: now) / 60).rounded(.up))
        return "\(totalMinutes / 60)h \(String(format: "%02d", totalMinutes % 60))m"
    }

    /// 今より前に作られた星のうち最新のもの（デバッグで日数を戻したときの未来の星は除外）
    private func latestPastStar(_ starDates: [Date], now: Date) -> Date? {
        starDates.filter { $0 <= now }.max()
    }
}
