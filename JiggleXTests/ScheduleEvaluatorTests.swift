import XCTest
@testable import JiggleX

final class ScheduleEvaluatorTests: XCTestCase {
    private let cal = newYorkCalendar
    private let weekdays = Schedule.default
    private var everyDay: Schedule {
        var s = Schedule.default
        s.days = Set(Weekday.allCases)
        return s
    }

    // 2026-10-21 is a Wednesday.

    func testInsideWindowOnWeekday() {
        XCTAssertTrue(ScheduleEvaluator.isInWindow(weekdays, at: date(2026, 10, 21, 10), calendar: cal))
    }

    func testStartIsInclusiveEndIsExclusive() {
        XCTAssertTrue(ScheduleEvaluator.isInWindow(weekdays, at: date(2026, 10, 21, 8), calendar: cal))
        XCTAssertTrue(ScheduleEvaluator.isInWindow(weekdays, at: date(2026, 10, 21, 17, 59), calendar: cal))
        XCTAssertFalse(ScheduleEvaluator.isInWindow(weekdays, at: date(2026, 10, 21, 18), calendar: cal))
    }

    func testWeekendIsOutside() {
        XCTAssertFalse(ScheduleEvaluator.isInWindow(weekdays, at: date(2026, 10, 24, 10), calendar: cal))
    }

    func testNoDaysNeverInWindowAndNoNextStart() {
        var s = Schedule.default
        s.days = []
        XCTAssertFalse(ScheduleEvaluator.isInWindow(s, at: date(2026, 10, 21, 10), calendar: cal))
        XCTAssertNil(ScheduleEvaluator.nextWindowStart(s, after: date(2026, 10, 21, 10), calendar: cal))
    }

    func testNextStartLaterToday() {
        XCTAssertEqual(ScheduleEvaluator.nextWindowStart(weekdays, after: date(2026, 10, 21, 7), calendar: cal),
                       date(2026, 10, 21, 8))
    }

    func testNextStartFromInsideWindowIsTomorrow() {
        XCTAssertEqual(ScheduleEvaluator.nextWindowStart(weekdays, after: date(2026, 10, 21, 10), calendar: cal),
                       date(2026, 10, 22, 8))
    }

    func testNextStartFromFridaySkipsWeekend() {
        XCTAssertEqual(ScheduleEvaluator.nextWindowStart(weekdays, after: date(2026, 10, 23, 10), calendar: cal),
                       date(2026, 10, 26, 8))
    }

    func testDSTSpringForwardDay() {
        XCTAssertTrue(ScheduleEvaluator.isInWindow(everyDay, at: date(2026, 3, 8, 10), calendar: cal))
        XCTAssertEqual(ScheduleEvaluator.nextWindowStart(everyDay, after: date(2026, 3, 8, 7), calendar: cal),
                       date(2026, 3, 8, 8))
    }

    func testDSTFallBackDay() {
        XCTAssertTrue(ScheduleEvaluator.isInWindow(everyDay, at: date(2026, 11, 1, 10), calendar: cal))
        XCTAssertEqual(ScheduleEvaluator.nextWindowStart(everyDay, after: date(2026, 11, 1, 7), calendar: cal),
                       date(2026, 11, 1, 8))
    }

    func testIsValidRequiresEndAfterStart() {
        var s = Schedule.default
        s.start = TimeOfDay(hour: 18, minute: 0)
        s.end = TimeOfDay(hour: 8, minute: 0)
        XCTAssertFalse(s.isValid)
        s.end = TimeOfDay(hour: 18, minute: 0)
        XCTAssertFalse(s.isValid)
        XCTAssertTrue(Schedule.default.isValid)
    }

    func testSummaryDefault() {
        XCTAssertEqual(Schedule.default.summary(calendar: cal), "Mon–Fri, 8:00 AM – 6:00 PM")
    }

    func testSummaryNonContiguousDays() {
        var s = Schedule.default
        s.days = [.monday, .wednesday, .thursday, .friday]
        XCTAssertEqual(s.summary(calendar: cal), "Mon, Wed–Fri, 8:00 AM – 6:00 PM")
    }

    func testSummaryNoDays() {
        var s = Schedule.default
        s.days = []
        XCTAssertEqual(s.summary(calendar: cal), "No working days")
    }

    func testDefaultValues() {
        let s = Schedule.default
        XCTAssertEqual(s.days, [.monday, .tuesday, .wednesday, .thursday, .friday])
        XCTAssertEqual(s.start, TimeOfDay(hour: 8, minute: 0))
        XCTAssertEqual(s.end, TimeOfDay(hour: 18, minute: 0))
        XCTAssertEqual(s.idleThreshold, 120)
    }
}
