import Foundation

/// Day of the week. Raw values match `Calendar`'s weekday component (1 = Sunday).
enum Weekday: Int, Codable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

/// A wall-clock time of day.
struct TimeOfDay: Codable, Equatable, Comparable {
    var hour: Int
    var minute: Int

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

/// The user's working-hours schedule: one `[start, end)` window on each enabled day.
struct Schedule: Codable, Equatable {
    var days: Set<Weekday>
    var start: TimeOfDay
    var end: TimeOfDay
    /// Seconds of no input before Jiggle-X declares user activity.
    var idleThreshold: TimeInterval

    static let `default` = Schedule(
        days: [.monday, .tuesday, .wednesday, .thursday, .friday],
        start: TimeOfDay(hour: 8, minute: 0),
        end: TimeOfDay(hour: 18, minute: 0),
        idleThreshold: 120
    )

    /// Must stay below Teams' ~5 minute Away timeout.
    static let idleThresholdRange: ClosedRange<TimeInterval> = 30...240

    /// Overnight windows aren't supported, so the window must end after it starts.
    var isValid: Bool { end > start }
}

extension Schedule {
    /// e.g. "Mon–Fri, 8:00 AM – 6:00 PM", with contiguous day runs collapsed.
    func summary(calendar: Calendar = .autoupdatingCurrent) -> String {
        guard !days.isEmpty else { return String(localized: "No working days") }

        let symbols = calendar.shortWeekdaySymbols
        let ordered = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        var runs: [[Int]] = []
        for weekday in ordered where days.contains(Weekday(rawValue: weekday)!) {
            if let last = runs.last?.last, ordered.firstIndex(of: last)! + 1 == ordered.firstIndex(of: weekday)! {
                runs[runs.count - 1].append(weekday)
            } else {
                runs.append([weekday])
            }
        }
        let dayText = runs.map { run in
            run.count == 1
                ? symbols[run[0] - 1]
                : "\(symbols[run.first! - 1])–\(symbols[run.last! - 1])"
        }.joined(separator: ", ")

        return "\(dayText), \(Self.format(start, calendar: calendar)) – \(Self.format(end, calendar: calendar))"
    }

    static func format(_ time: TimeOfDay, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        let date = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: time.hour, minute: time.minute))!
        // Newer ICU uses a narrow no-break space before AM/PM; plain spaces read the same in a menu.
        return formatter.string(from: date).replacingOccurrences(of: "\u{202F}", with: " ")
    }
}
