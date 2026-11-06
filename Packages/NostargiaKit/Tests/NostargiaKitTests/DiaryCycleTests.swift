import Foundation
import Testing
@testable import NostargiaKit

struct DiaryCycleTests {
    static func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    let tokyo = calendar("Asia/Tokyo")
    var cycle: DiaryCycle { DiaryCycle(calendar: tokyo) }

    func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0, _ s: Int = 0, calendar: Calendar? = nil) -> Date {
        (calendar ?? tokyo).date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    struct GoldenCase: Decodable {
        let at: Double
        let start: Double
        let end: Double
    }

    @Test func boundariesMatchWeb() throws {
        let cases = try Fixture.load("diary_cycle", as: [GoldenCase].self)
        #expect(cases.count == 151)
        for c in cases {
            let at = Date(timeIntervalSince1970: c.at / 1000)
            #expect(cycle.start(containing: at).timeIntervalSince1970 * 1000 == c.start, "\(at)")
            #expect(cycle.end(containing: at).timeIntervalSince1970 * 1000 == c.end, "\(at)")
        }
    }

    @Test func dstDayIsTwentyThreeHours() {
        let newYork = Self.calendar("America/New_York")
        let dstCycle = DiaryCycle(calendar: newYork)
        // 2026-03-08 2:00 に夏時間が始まるので、3/7 6:00〜3/8 6:00 の周期が23時間になる
        let noon = date(2026, 3, 7, 12, calendar: newYork)
        let start = dstCycle.start(containing: noon)
        #expect(start == date(2026, 3, 7, 6, calendar: newYork))
        #expect(dstCycle.end(containing: noon) == date(2026, 3, 8, 6, calendar: newYork))
        #expect(dstCycle.end(containing: noon).timeIntervalSince(start) == 23 * 3600)
    }

    @Test func noStarsMeansReady() {
        #expect(!cycle.isCooldownActive(starDates: [], now: date(2026, 11, 6, 12)))
        #expect(cycle.cooldownProgress(starDates: [], now: date(2026, 11, 6, 12)) == 1)
    }

    @Test func starInCurrentCycleStartsCooldown() {
        let stars = [date(2026, 11, 6, 7)]
        #expect(cycle.isCooldownActive(starDates: stars, now: date(2026, 11, 7, 5, 59)))
        #expect(!cycle.isCooldownActive(starDates: stars, now: date(2026, 11, 7, 6)))
    }

    @Test func starBeforeSixBelongsToPreviousCycle() {
        let stars = [date(2026, 11, 6, 5, 59)]
        #expect(!cycle.isCooldownActive(starDates: stars, now: date(2026, 11, 6, 6)))
    }

    @Test func futureStarsAreIgnored() {
        // デバッグで日数を戻したとき、今より後の星は数えない
        let stars = [date(2026, 11, 6, 8), date(2026, 11, 9, 8)]
        let now = date(2026, 11, 7, 12)
        #expect(!cycle.isCooldownActive(starDates: stars, now: now))
        #expect(cycle.cooldownProgress(starDates: stars, now: now) == 1)
    }

    @Test func progressIsElapsedShareOfCycle() {
        let stars = [date(2026, 11, 6, 7)]
        #expect(abs(cycle.cooldownProgress(starDates: stars, now: date(2026, 11, 6, 18)) - 0.5) < 1e-12)
    }

    @Test func remainingText() {
        // 残り59分30秒 → 分は切り上げで 60分 → "1h 00m"
        #expect(cycle.cooldownText(now: date(2026, 11, 6, 5, 0, 30)) == "1h 00m")
        #expect(cycle.cooldownText(now: date(2026, 11, 6, 6)) == "24h 00m")
        #expect(cycle.cooldownRemaining(now: date(2026, 11, 6, 22, 30)) == 7.5 * 3600)
    }

    @Test func appClockAddsDebugDays() {
        let base = date(2026, 11, 6, 12)
        let clock = AppClock(debugDayOffset: 2, calendar: tokyo, base: { base })
        #expect(clock.now() == date(2026, 11, 8, 12))
        #expect(AppClock(calendar: tokyo, base: { base }).now() == base)
    }
}
