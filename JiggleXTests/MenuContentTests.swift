import XCTest
@testable import JiggleX

final class MenuContentTests: XCTestCase {
    private let cal = newYorkCalendar

    func testStatusTitles() {
        XCTAssertEqual(MenuContent.statusTitle(.active, calendar: cal), "Active — keeping you available")
        XCTAssertEqual(MenuContent.statusTitle(.paused, calendar: cal), "Paused")
        XCTAssertEqual(MenuContent.statusTitle(.pausedUntil(date(2026, 10, 26, 8)), calendar: cal),
                       "Paused until Mon 8:00 AM")
        XCTAssertEqual(MenuContent.statusTitle(.outsideHours, calendar: cal), "Outside working hours")
    }

    func testActions() {
        XCTAssertEqual(MenuContent.actions(for: .active), [.pause, .pauseUntilTomorrow])
        XCTAssertEqual(MenuContent.actions(for: .paused), [.resume])
        XCTAssertEqual(MenuContent.actions(for: .pausedUntil(date(2026, 10, 26, 8))), [.resume])
        XCTAssertEqual(MenuContent.actions(for: .outsideHours), [.pause])
    }
}
