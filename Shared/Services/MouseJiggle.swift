import AppKit
import ApplicationServices
import CoreGraphics

/// Posts synthetic mouse events. Requires the Accessibility permission.
protocol EventPoster {
    func hasAccess() -> Bool
    func cursorLocation() -> CGPoint?
    @discardableResult func postMouseMove(to point: CGPoint) -> Bool
}

/// The Accessibility ("post events") permission.
enum AccessibilityPermission {
    static var isGranted: Bool { CGPreflightPostEventAccess() }

    /// Shows the system prompt (once) and adds Jiggle-X to the Accessibility list.
    static func request() { _ = CGRequestPostEventAccess() }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

struct SystemEventPoster: EventPoster {
    func hasAccess() -> Bool { AccessibilityPermission.isGranted }

    func cursorLocation() -> CGPoint? {
        CGEvent(source: nil)?.location // global, top-left origin — same space as mouse events
    }

    func postMouseMove(to point: CGPoint) -> Bool {
        // A HID-level source makes the event count as real input, resetting the
        // system idle time that Teams reads.
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved,
                                  mouseCursorPosition: point, mouseButton: .left) else { return false }
        event.post(tap: .cghidEventTap)
        return true
    }
}

/// Jiggles the cursor one pixel and straight back — real input, so Teams'
/// idle timer resets — and declares user activity so a sleeping display wakes.
final class MouseJiggleNudger: ActivityNudger {
    private let poster: EventPoster
    private let displayWaker: ActivityNudger

    init(poster: EventPoster, displayWaker: ActivityNudger) {
        self.poster = poster
        self.displayWaker = displayWaker
    }

    @discardableResult
    func declareActivity() -> Bool {
        displayWaker.declareActivity()
        guard poster.hasAccess(), let origin = poster.cursorLocation() else { return false }
        let moved = poster.postMouseMove(to: CGPoint(x: origin.x + 1, y: origin.y))
        let returned = poster.postMouseMove(to: origin)
        return moved && returned
    }

    func release() {
        displayWaker.release()
    }
}
