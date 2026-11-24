import AppKit

/// The run-state machine. Each tick re-derives the state from the schedule, the
/// pause state and the clock, then declares activity if the user has gone idle
/// during an active window. Deriving every tick (rather than scheduling boundary
/// timers) means sleep, clock and timezone changes need no special handling
/// beyond triggering a tick.
@MainActor
final class ActivityController {
    static let tickInterval: TimeInterval = 15
    /// Input this close after our own jiggle is the jiggle itself, not the user.
    static let jiggleEchoSlack: TimeInterval = 2

    private(set) var state: RunState = .outsideHours
    var onStateChange: ((RunState) -> Void)?

    private let persistence: PersistenceManager
    private let idleMonitor: IdleMonitor
    private let nudger: ActivityNudger
    private let clock: NowProvider
    private let napPreventer: NapPreventer
    private let eventLog: EventLog
    private let calendar: Calendar
    private var timer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    // Random breaks. Our jiggles reset the HID idle time, so "the user hasn't touched
    // anything" can't be read from idle time alone: we remember when we last jiggled
    // and treat any later input as the user's.
    private let randomDuration: (ClosedRange<TimeInterval>) -> TimeInterval
    private var lastJiggleAt: Date?
    private var lastRealInputAt: Date?
    /// The break clock counts from the later of this and `lastRealInputAt`.
    private var breakClockStart: Date?
    private var breakStartedAt: Date?
    /// While set, no jiggles are made until this time (or until the user is back).
    private(set) var breakUntil: Date?

    init(persistence: PersistenceManager, idleMonitor: IdleMonitor, nudger: ActivityNudger,
         clock: NowProvider, napPreventer: NapPreventer, eventLog: EventLog, calendar: Calendar = .autoupdatingCurrent,
         randomDuration: @escaping (ClosedRange<TimeInterval>) -> TimeInterval = { .random(in: $0) }) {
        self.persistence = persistence
        self.idleMonitor = idleMonitor
        self.nudger = nudger
        self.clock = clock
        self.napPreventer = napPreventer
        self.eventLog = eventLog
        self.calendar = calendar
        self.randomDuration = randomDuration
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
        // Each active stretch starts with a fresh break clock and no break.
        breakStartedAt = nil
        breakUntil = nil
        breakClockStart = now
        state = newState
        eventLog.log("State → \(newState)", category: "Activity")
        onStateChange?(newState)
    }

    func tick() {
        refresh()
        guard state == .active else { return }
        let now = clock.now()
        let idle = idleMonitor.secondsSinceLastInput()
        let lastInputAt = now.addingTimeInterval(-idle)
        if lastJiggleAt.map({ lastInputAt > $0.addingTimeInterval(Self.jiggleEchoSlack) }) ?? true {
            lastRealInputAt = lastInputAt
        }
        if isOnBreak(now: now) { return }

        let threshold = persistence.schedule.idleThreshold
        // Only jiggles are logged: a line every 15s while the user is working is noise.
        guard idle >= threshold else { return }
        let result = nudger.declareActivity() ? "ok" : "FAILED"
        lastJiggleAt = clock.now()
        eventLog.log("Tick: idle \(Int(idle))s (threshold \(Int(threshold))s) → declared activity: \(result)",
                     category: "Activity")
    }

    /// Starts, continues or ends a random break; true while jiggles should be held off.
    private func isOnBreak(now: Date) -> Bool {
        if let breakStartedAt, let breakUntil {
            if let lastRealInputAt, lastRealInputAt > breakStartedAt {
                endBreak(at: now, reason: "input detected")
            } else if now < breakUntil {
                return true
            } else {
                endBreak(at: now, reason: "break over")
            }
            return false
        }

        let settings = persistence.breakSettings
        guard settings.isEnabled, let lastJiggleAt else { return false }
        let since = [lastRealInputAt, breakClockStart].compactMap { $0 }.max() ?? now
        // Only once we've actually been jiggling for the user since then.
        guard lastJiggleAt > since,
              now.timeIntervalSince(since) >= TimeInterval(settings.afterMinutes * 60) else { return false }

        let duration = randomDuration(settings.breakDurationRange)
        breakStartedAt = now
        breakUntil = now.addingTimeInterval(duration)
        nudger.release()
        eventLog.log("Break: no input for \(Int(now.timeIntervalSince(since) / 60))m → no jiggles for \(Int(duration))s",
                     category: "Activity")
        return true
    }

    private func endBreak(at now: Date, reason: String) {
        breakStartedAt = nil
        breakUntil = nil
        breakClockStart = now
        eventLog.log("Break ended (\(reason))", category: "Activity")
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
        let timer = Timer(timeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Let macOS batch this wakeup with others; a few seconds' slack doesn't matter.
        timer.tolerance = Self.tickInterval / 3
        // .common keeps ticking while a menu is open (event-tracking mode).
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
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
