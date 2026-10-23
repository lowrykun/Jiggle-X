import CoreGraphics
import XCTest
@testable import JiggleX

final class FakeEventPoster: EventPoster {
    var access = true
    var location: CGPoint? = CGPoint(x: 500, y: 300)
    private(set) var moves: [CGPoint] = []
    func hasAccess() -> Bool { access }
    func cursorLocation() -> CGPoint? { location }
    func postMouseMove(to point: CGPoint) -> Bool { moves.append(point); return true }
}

final class MouseJiggleNudgerTests: XCTestCase {
    private var poster: FakeEventPoster!
    private var fallback: FakeNudger!
    private var nudger: MouseJiggleNudger!

    override func setUp() {
        poster = FakeEventPoster()
        fallback = FakeNudger()
        nudger = MouseJiggleNudger(poster: poster, displayWaker: fallback)
    }

    func testMovesOnePixelAndBack() {
        XCTAssertTrue(nudger.declareActivity())
        XCTAssertEqual(poster.moves, [CGPoint(x: 501, y: 300), CGPoint(x: 500, y: 300)])
    }

    func testAlsoDeclaresActivityToWakeDisplay() {
        nudger.declareActivity()
        XCTAssertEqual(fallback.nudges, 1)
    }

    func testFailsWithoutAccessibilityAndPostsNothing() {
        poster.access = false
        XCTAssertFalse(nudger.declareActivity())
        XCTAssertTrue(poster.moves.isEmpty)
        XCTAssertEqual(fallback.nudges, 1)
    }

    func testFailsWhenCursorLocationUnknown() {
        poster.location = nil
        XCTAssertFalse(nudger.declareActivity())
        XCTAssertTrue(poster.moves.isEmpty)
    }

    func testReleaseReleasesDisplayAssertion() {
        nudger.release()
        XCTAssertEqual(fallback.releases, 1)
    }
}
