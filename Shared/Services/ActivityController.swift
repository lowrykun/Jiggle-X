import AppKit
import os.log

/// The run-state machine. Each tick re-derives the state from the schedule, the
/// pause state and the clock, then declares activity if the user has gone idle
/// during an active window. Deriving every tick (rather than scheduling boundary
/// timers) means sleep, clock and timezone changes need no special handling
/// beyond triggering a tick.
@MainActor
final class ActivityController {
    static let tickInterval: TimeInterval = 15

    private(set) var state: RunState = .outsideHours
    var onStateChange: ((RunState) -> Void)?

    private let persistence: PersistenceManager
    private let idleMonitor: IdleMonitor
    private let nudger: ActivityNudger
    private let clock: NowProvider
    private let napPreventer: NapPreventer
    private let calendar: Calendar
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "Activity")

    init(persistence: PersistenceManager, idleMonitor: IdleMonitor, nudger: ActivityNudger,
         clock: NowProvider, napPreventer: NapPreventer, calendar: Calendar = .autoupdatingCurrent) {
        self.persistence = persistence
        self.idleMonitor = idleMonitor
        self.nudger = nudger
        self.clock = clock
        self.napPreventer = napPreventer
        self.calendar = calendar
    }

    /// Re-derive `state`, clearing a "Pause Until Tomorrow" whose time has come.
    func refresh() {
        let now = clock.now()
        if case .untilNextWindow(let resumeAt) = persistence.pauseState, now >= resumeAt {
            persistence.pauseState = .none
        }

        let newState: RunState
        switch persistence.pauseState {
        case .paused:
            newState = .paused
        case .untilNextWindow(let resumeAt):
            newState = .pausedUntil(resumeAt)
        case .none:
            newState = ScheduleEvaluator.isInWindow(persistence.schedule, at: now, calendar: calendar)
                ? .active : .outsideHours
        }

        guard newState != state else { return }
        if state == .active { nudger.release() }
        if newState == .active { napPreventer.begin() } else { napPreventer.end() }
        state = newState
        logger.info("State → \(String(describing: newState), privacy: .public)")
        onStateChange?(newState)
    }

    func tick() {
        refresh()
        guard state == .active else { return }
        let idle = idleMonitor.secondsSinceLastInput()
        if idle >= persistence.schedule.idleThreshold {
            let ok = nudger.declareActivity()
            logger.info("Idle \(Int(idle), privacy: .public)s → declared activity (ok: \(ok, privacy: .public))")
        }
    }

    func pause() {
        persistence.pauseState = .paused
        refresh()
    }

    /// Only meaningful while active: resumes at the next window start.
    func pauseUntilTomorrow() {
        guard state == .active,
              let resumeAt = ScheduleEvaluator.nextWindowStart(persistence.schedule, after: clock.now(), calendar: calendar)
        else { return }
        persistence.pauseState = .untilNextWindow(resumeAt: resumeAt)
        refresh()
    }

    func resume() {
        persistence.pauseState = .none
        refresh()
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        let center = NotificationCenter.default
        let triggers: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didWakeNotification),
            (workspace, NSWorkspace.screensDidWakeNotification),
            (center, .NSSystemTimeZoneDidChange),
            (center, .NSSystemClockDidChange),
        ]
        observers = triggers.map { center, name in
            (center, center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            })
        }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        observers.forEach { center, token in center.removeObserver(token) }
        observers = []
        nudger.release()
        napPreventer.end()
    }
}
