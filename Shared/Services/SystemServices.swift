import CoreGraphics
import Foundation
import IOKit.pwr_mgt

/// Seconds since the user last touched the keyboard, mouse or trackpad.
protocol IdleMonitor {
    func secondsSinceLastInput() -> TimeInterval
}

/// Tells macOS the user is active.
protocol ActivityNudger {
    @discardableResult func declareActivity() -> Bool
    func release()
}

protocol NowProvider {
    func now() -> Date
}

struct SystemIdleMonitor: IdleMonitor {
    func secondsSinceLastInput() -> TimeInterval {
        // ~0 is kCGAnyInputEventType: the most recent event of any kind.
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }
}

/// Declares user activity with a power assertion. This resets the system idle timer
/// (which is what Teams watches), keeps the display on, and wakes it if asleep —
/// without moving the cursor or needing the Accessibility permission.
final class PowerAssertionNudger: ActivityNudger {
    private var assertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)

    @discardableResult
    func declareActivity() -> Bool {
        let result = IOPMAssertionDeclareUserActivity("Jiggle-X: working hours" as CFString, kIOPMUserActiveLocal, &assertionID)
        return result == kIOReturnSuccess
    }

    func release() {
        guard assertionID != IOPMAssertionID(kIOPMNullAssertionID) else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(kIOPMNullAssertionID)
    }
}

struct SystemNowProvider: NowProvider {
    func now() -> Date { Date() }
}
