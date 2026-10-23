import XCTest
@testable import JiggleX

final class PersistenceManagerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var persistence: PersistenceManager!

    override func setUp() {
        defaults = UserDefaults(suiteName: UUID().uuidString)!
        persistence = PersistenceManager(defaults: defaults)
    }

    func testDefaultsOnFirstLaunch() {
        XCTAssertEqual(persistence.schedule, .default)
        XCTAssertEqual(persistence.pauseState, PauseState.none)
        XCTAssertFalse(persistence.hasLaunchedBefore)
    }

    func testScheduleRoundTrip() {
        var s = Schedule.default
        s.days = [.saturday]
        s.start = TimeOfDay(hour: 9, minute: 30)
        s.idleThreshold = 60
        persistence.schedule = s
        XCTAssertEqual(PersistenceManager(defaults: defaults).schedule, s)
    }

    func testPauseStateRoundTrip() {
        for state in [PauseState.none, .paused, .untilNextWindow(resumeAt: date(2026, 10, 26, 8))] {
            persistence.pauseState = state
            XCTAssertEqual(PersistenceManager(defaults: defaults).pauseState, state)
        }
    }

    func testHasLaunchedBeforeRoundTrip() {
        persistence.hasLaunchedBefore = true
        XCTAssertTrue(PersistenceManager(defaults: defaults).hasLaunchedBefore)
    }

    func testCorruptScheduleDataFallsBackToDefault() {
        defaults.set(Data([0xFF]), forKey: Constants.Keys.schedule)
        XCTAssertEqual(persistence.schedule, .default)
    }

    func testCorruptPauseStateFallsBackToNone() {
        defaults.set(Data([0xFF]), forKey: Constants.Keys.pauseState)
        XCTAssertEqual(persistence.pauseState, PauseState.none)
    }

    func testInvalidScheduleFallsBackToDefault() {
        var s = Schedule.default
        s.end = TimeOfDay(hour: 7, minute: 0)
        defaults.set(try! JSONEncoder().encode(s), forKey: Constants.Keys.schedule)
        XCTAssertEqual(persistence.schedule, .default)
    }

    func testIdleThresholdClampedOnRead() {
        var s = Schedule.default
        s.idleThreshold = 10
        persistence.schedule = s
        XCTAssertEqual(persistence.schedule.idleThreshold, 30)
        s.idleThreshold = 999
        persistence.schedule = s
        XCTAssertEqual(persistence.schedule.idleThreshold, 240)
    }
}
