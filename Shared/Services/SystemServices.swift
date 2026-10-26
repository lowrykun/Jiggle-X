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

/// Keeps macOS from App Napping the process, which would stretch the tick timer
/// far past Teams' Away timeout.
protocol NapPreventer {
    func begin()
    func end()
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
    typealias Declare = (inout IOPMAssertionID) -> IOReturn

    private var assertionID: IOPMAssertionID = IOPMAssertionID(kIOPMNullAssertionID)
    private let declare: Declare

    init(declare: @escaping Declare = { id in
        IOPMAssertionDeclareUserActivity("Jiggle-X: working hours" as CFString, kIOPMUserActiveLocal, &id)
    }) {
        self.declare = declare
    }

    @discardableResult
    func declareActivity() -> Bool {
        if declare(&assertionID) == kIOReturnSuccess { return true }
        // The reused ID may have gone stale (e.g. powerd restarted); start a fresh assertion.
        assertionID = IOPMAssertionID(kIOPMNullAssertionID)
        return declare(&assertionID) == kIOReturnSuccess
    }

    func release() {
        guard assertionID != IOPMAssertionID(kIOPMNullAssertionID) else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = IOPMAssertionID(kIOPMNullAssertionID)
    }
}

final class SystemNapPreventer: NapPreventer {
    private var activity: NSObjectProtocol?

    func begin() {
        guard activity == nil else { return }
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Keeping you available during working hours"
        )
    }

    func end() {
        guard let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
    }
}

struct SystemNowProvider: NowProvider {
    func now() -> Date { Date() }
}
