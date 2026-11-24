import XCTest
@testable import JiggleX

/// Simulates real time: every tick advances the clock 15 s, and HID idle time is
/// measured from the later of the user's last input and our last jiggle.
@MainActor
final class RandomBreakTests: XCTestCase {
    private var persistence: PersistenceManager!
    private var idle: FakeIdleMonitor!
    private var nudger: FakeNudger!
    private var clock: FakeClock!
    private var eventLog: FakeEventLog!
    private var controller: ActivityController!
    private var lastEventAt: Date!
    private var requestedRanges: [ClosedRange<TimeInterval>] = []

    override func setUp() async throws {
        persistence = PersistenceManager(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        persistence.breakSettings = BreakSettings(isEnabled: true, afterMinutes: 15, maxBreakMinutes: 10)
        idle = FakeIdleMonitor()
        nudger = FakeNudger()
        clock = FakeClock(date(2026, 10, 21, 10))
        eventLog = FakeEventLog()
        requestedRanges = []
        controller = ActivityController(persistence: persistence, idleMonitor: idle, nudger: nudger,
                                        clock: clock, napPreventer: FakeNapPreventer(), eventLog: eventLog,
                                        calendar: newYorkCalendar,
                                        randomDuration: { [unowned self] range in
                                            requestedRanges.append(range)
                                            return 300 // 5 minute break
                                        })
        controller.refresh()
        lastEventAt = clock.current
    }

    /// Advances `minutes` of ticks with no user input; returns jiggles made.
    @discardableResult
    private func runIdle(minutes: Double) -> Int {
        let before = nudger.nudges
        for _ in 0..<Int(minutes * 4) {
            clock.current += ActivityController.tickInterval
            idle.idle = clock.current.timeIntervalSince(lastEventAt)
            let count = nudger.nudges
            controller.tick()
            if nudger.nudges > count { lastEventAt = clock.current }
        }
        return nudger.nudges - before
    }

    private func userTouchesMouse() { lastEventAt = clock.current }

    func testDisabledNeverBreaks() {
        persistence.breakSettings = .default
        runIdle(minutes: 60)
        XCTAssertNil(controller.breakUntil)
        XCTAssertFalse(eventLog.lines.contains { $0.contains("Break") })
    }

    func testBreaksAfterXMinutesWithoutRealInput() {
        runIdle(minutes: 14.75)
        XCTAssertNil(controller.breakUntil)
        runIdle(minutes: 0.25)
        XCTAssertEqual(controller.breakUntil, clock.current + 300)
        XCTAssertEqual(requestedRanges, [60...600])
        XCTAssertEqual(nudger.releases, 1)
    }

    func testNoJigglesDuringBreakThenResumes() {
        runIdle(minutes: 15)
        XCTAssertEqual(runIdle(minutes: 4.75), 0)
        XCTAssertNotNil(controller.breakUntil)
        XCTAssertEqual(runIdle(minutes: 0.25), 1) // break over: idle is long, jiggle at once
        XCTAssertNil(controller.breakUntil)
        XCTAssertTrue(eventLog.lines.contains("[Activity] Break ended (break over)"))
    }

    func testBreakClockRestartsAfterBreak() {
        runIdle(minutes: 15 + 5) // first break ends
        runIdle(minutes: 14.75)
        XCTAssertNil(controller.breakUntil)
        runIdle(minutes: 0.25)
        XCTAssertNotNil(controller.breakUntil)
        XCTAssertEqual(requestedRanges.count, 2)
    }

    func testRealInputResetsBreakClock() {
        runIdle(minutes: 9) // between jiggles (they land on even minutes)
        userTouchesMouse()
        runIdle(minutes: 14.75)
        XCTAssertNil(controller.breakUntil)
        runIdle(minutes: 0.25)
        XCTAssertNotNil(controller.breakUntil)
    }

    func testRealInputEndsBreakEarly() {
        runIdle(minutes: 16)
        XCTAssertNotNil(controller.breakUntil)
        userTouchesMouse()
        runIdle(minutes: 0.25)
        XCTAssertNil(controller.breakUntil)
        XCTAssertTrue(eventLog.lines.contains("[Activity] Break ended (input detected)"))
    }

    func testNoBreakWhileUserIsWorking() {
        for _ in 0..<60 { // an hour of touching the mouse every minute
            runIdle(minutes: 1)
            userTouchesMouse()
        }
        XCTAssertEqual(nudger.nudges, 0)
        XCTAssertTrue(requestedRanges.isEmpty)
    }

    func testPauseClearsBreak() {
        runIdle(minutes: 16)
        controller.pause()
        controller.resume()
        XCTAssertNil(controller.breakUntil)
    }
}
