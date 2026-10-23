import Foundation

enum MenuAction: Equatable {
    case pause, pauseUntilTomorrow, resume
}

/// What the left-click status menu shows for each run state.
enum MenuContent {
    static func statusTitle(_ state: RunState, calendar: Calendar = .autoupdatingCurrent) -> String {
        switch state {
        case .active:
            return String(localized: "Active — keeping you available")
        case .paused:
            return String(localized: "Paused")
        case .pausedUntil(let resumeAt):
            let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: resumeAt) - 1]
            let parts = calendar.dateComponents([.hour, .minute], from: resumeAt)
            let time = Schedule.format(TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0), calendar: calendar)
            return String(localized: "Paused until \(weekday) \(time)")
        case .outsideHours:
            return String(localized: "Outside working hours")
        }
    }

    static func actions(for state: RunState) -> [MenuAction] {
        switch state {
        case .active: return [.pause, .pauseUntilTomorrow]
        case .paused, .pausedUntil: return [.resume]
        case .outsideHours: return [.pause]
        }
    }
}
