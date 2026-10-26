import XCTest
@testable import JiggleX

final class AppLogTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeLog(maxBytes: Int = 1_000_000) -> AppLog {
        AppLog(directory: dir, maxBytes: maxBytes, clock: FakeClock(date(2026, 10, 23, 9, 5)), timeZone: newYorkCalendar.timeZone)
    }

    func testWritesTimestampedLineWithCategory() {
        let log = makeLog()
        log.log("State → active", category: "Activity")
        XCTAssertEqual(log.read(), "2026-10-23 09:05:00 [Activity] State → active\n")
    }

    func testAppendsLines() {
        let log = makeLog()
        log.log("one", category: "A")
        log.log("two", category: "B")
        XCTAssertEqual(log.read().split(separator: "\n").count, 2)
    }

    func testCreatesDirectoryIfMissing() {
        makeLog().log("x", category: "A")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Jiggle-X.log").path))
    }

    func testRotatesWhenOverMaxBytes() {
        let log = makeLog(maxBytes: 100)
        for i in 0..<10 { log.log("line \(i) padding padding", category: "A") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("Jiggle-X.1.log").path))
        XCTAssertLessThanOrEqual(log.read().utf8.count, 100)
        XCTAssertTrue(log.read().contains("line 9"))
    }

    func testClearEmptiesLog() {
        let log = makeLog()
        log.log("x", category: "A")
        log.clear()
        XCTAssertEqual(log.read(), "")
    }

    func testPostsDidAppendWithLine() {
        let log = makeLog()
        let posted = expectation(forNotification: AppLog.didAppend, object: log) { note in
            note.userInfo?[AppLog.lineKey] as? String == "2026-10-23 09:05:00 [A] hello\n"
        }
        log.log("hello", category: "A")
        wait(for: [posted], timeout: 1)
    }

    func testTailKeepsLastLines() {
        XCTAssertEqual(AppLog.tail(of: "a\nb\nc\nd\n", maxLines: 2), "c\nd\n")
    }

    func testTailOfShortTextIsUnchanged() {
        XCTAssertEqual(AppLog.tail(of: "a\nb\n", maxLines: 5), "a\nb\n")
    }

    func testReadWithNoFileIsEmpty() {
        XCTAssertEqual(makeLog().read(), "")
    }
}
