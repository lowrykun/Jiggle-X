import XCTest
@testable import JiggleX

final class FakeIdleMonitor: IdleMonitor {
    var idle: TimeInterval = 0
    func secondsSinceLastInput() -> TimeInterval { idle }
}

final class FakeNudger: ActivityNudger {
    private(set) var nudges = 0
    private(set) var releases = 0
    func declareActivity() -> Bool { nudges += 1; return true }
    func release() { releases += 1 }
}

final class FakeNapPreventer: NapPreventer {
    private(set) var isHeld = false
    func begin() { isHeld = true }
    func end() { isHeld = false }
}

final class FakeEventLog: EventLog {
    private(set) var lines: [String] = []
    func log(_ message: String, category: String) { lines.append("[\(category)] \(message)") }
}

final class FakeClock: NowProvider {
    var current: Date
    init(_ current: Date) { self.current = current }
    func now() -> Date { current }
}

@MainActor
final class ActivityControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var persistence: PersistenceManager!
    private var idle: FakeIdleMonitor!
    private var nudger: FakeNudger!
    private var clock: FakeClock!
    private var napPreventer: FakeNapPreventer!
    private var eventLog: FakeEventLog!

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: UUID().uuidString)!
        persistence = PersistenceManager(defaults: defaults)
        idle = FakeIdleMonitor()
        nudger = FakeNudger()
        clock = FakeClock(date(2026, 10, 21, 10)) // Wednesday 10:00
        napPreventer = FakeNapPreventer()
        eventLog = FakeEventLog()
    }

    private func makeController() -> ActivityController {
        let controller = ActivityController(persistence: persistence, idleMonitor: idle, nudger: nudger,
                                            clock: clock, napPreventer: napPreventer, eventLog: eventLog,
                                            calendar: newYorkCalendar)
        controller.refresh()
        return controller
    }

    func testActiveInWindow() {
        XCTAssertEqual(makeController().state, .active)
    }

    func testOutsideHoursOnWeekend() {
        clock.current = date(2026, 10, 24, 10)
        XCTAssertEqual(makeController().state, .outsideHours)
    }

    func testNudgesWhenIdleAtThreshold() {
        let controller = makeController()
        idle.idle = 120
        controller.tick()
        XCTAssertEqual(nudger.nudges, 1)
    }

    func testNoNudgeBelowThreshold() {
        let controller = makeController()
        idle.idle = 119
        controller.tick()
        XCTAssertEqual(nudger.nudges, 0)
    }

    func testNeverNudgesOutsideHours() {
        clock.current = date(2026, 10, 21, 19)
        let controller = makeController()
        idle.idle = 9999
        controller.tick()
        XCTAssertEqual(nudger.nudges, 0)
    }

    func testNeverNudgesWhenPaused() {
        let controller = makeController()
        controller.pause()
        idle.idle = 9999
        controller.tick()
        XCTAssertEqual(nudger.nudges, 0)
        XCTAssertEqual(controller.state, .paused)
    }

    func testPauseResume() {
        let controller = makeController()
        controller.pause()
        XCTAssertEqual(persistence.pauseState, .paused)
        controller.resume()
        XCTAssertEqual(persistence.pauseState, PauseState.none)
        XCTAssertEqual(controller.state, .active)
    }

    func testPauseOutsideHoursIsAllowed() {
        clock.current = date(2026, 10, 21, 19)
        let controller = makeController()
        controller.pause()
        XCTAssertEqual(controller.state, .paused)
        controller.resume()
        XCTAssertEqual(controller.state, .outsideHours)
    }

    func testPauseUntilTomorrowFridayResumesMonday() {
        clock.current = date(2026, 10, 23, 10) // Friday
        let controller = makeController()
        controller.pauseUntilTomorrow()
        XCTAssertEqual(controller.state, .pausedUntil(date(2026, 10, 26, 8)))

        clock.current = date(2026, 10, 26, 8)
        controller.tick()
        XCTAssertEqual(controller.state, .active)
        XCTAssertEqual(persistence.pauseState, PauseState.none)
    }

    func testPauseUntilTomorrowIgnoredOutsideHours() {
        clock.current = date(2026, 10, 21, 19)
        let controller = makeController()
        controller.pauseUntilTomorrow()
        XCTAssertEqual(controller.state, .outsideHours)
        XCTAssertEqual(persistence.pauseState, PauseState.none)
    }

    func testRelaunchAfterResumeTimePassedClearsPause() {
        persistence.pauseState = .untilNextWindow(resumeAt: date(2026, 10, 20, 8))
        XCTAssertEqual(makeController().state, .active)
        XCTAssertEqual(persistence.pauseState, PauseState.none)
    }

    func testPausePersistsAcrossRelaunch() {
        makeController().pause()
        XCTAssertEqual(makeController().state, .paused)
    }

    func testWakePastWindowEndGoesOutsideHoursWithoutNudge() {
        clock.current = date(2026, 10, 21, 17, 50)
        let controller = makeController()
        clock.current = date(2026, 10, 21, 19)
        idle.idle = 9999
        controller.tick()
        XCTAssertEqual(controller.state, .outsideHours)
        XCTAssertEqual(nudger.nudges, 0)
        XCTAssertEqual(nudger.releases, 1)
    }

    func testOnStateChangeFiresOnlyOnChange() {
        let controller = makeController()
        var changes: [RunState] = []
        controller.onStateChange = { changes.append($0) }
        controller.tick()
        controller.tick()
        controller.pause()
        controller.tick()
        XCTAssertEqual(changes, [.paused])
    }

    func testScheduleChangeAppliesOnRefresh() {
        let controller = makeController()
        var s = Schedule.default
        s.days = [.saturday]
        persistence.schedule = s
        controller.refresh()
        XCTAssertEqual(controller.state, .outsideHours)
    }

    func testHoldsNapPreventionOnlyWhileActive() {
        let controller = makeController()
        XCTAssertTrue(napPreventer.isHeld)
        controller.pause()
        XCTAssertFalse(napPreventer.isHeld)
        controller.resume()
        XCTAssertTrue(napPreventer.isHeld)
        clock.current = date(2026, 10, 21, 19)
        controller.tick()
        XCTAssertFalse(napPreventer.isHeld)
    }

    func testLogsStateChanges() {
        let controller = makeController()
        controller.pause()
        XCTAssertEqual(eventLog.lines, ["[Activity] State → active", "[Activity] State → paused"])
    }

    func testLogsIdleAndNudgeOnEachActiveTick() {
        let controller = makeController()
        idle.idle = 30
        controller.tick()
        idle.idle = 125
        controller.tick()
        XCTAssertEqual(Array(eventLog.lines.suffix(2)), [
            "[Activity] Tick: idle 30s (threshold 120s)",
            "[Activity] Tick: idle 125s (threshold 120s) → declared activity: ok",
        ])
    }

    func testDoesNotLogTicksOutsideHours() {
        clock.current = date(2026, 10, 21, 19)
        let controller = makeController()
        controller.tick()
        XCTAssertTrue(eventLog.lines.isEmpty)
    }
}
