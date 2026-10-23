import Foundation

/// Pure schedule math: is a moment inside a working window, and when does the next one start?
enum ScheduleEvaluator {
    static func isInWindow(_ schedule: Schedule, at date: Date, calendar: Calendar) -> Bool {
        guard let window = window(schedule, on: date, calendar: calendar) else { return false }
        return window.start <= date && date < window.end
    }

    /// The first window start strictly after `date`, or nil if no days are enabled.
    static func nextWindowStart(_ schedule: Schedule, after date: Date, calendar: Calendar) -> Date? {
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: date),
                  let window = window(schedule, on: day, calendar: calendar),
                  window.start > date else { continue }
            return window.start
        }
        return nil
    }

    /// The `[start, end)` window on `date`'s day, or nil if that day isn't a working day.
    private static func window(_ schedule: Schedule, on date: Date, calendar: Calendar) -> (start: Date, end: Date)? {
        guard schedule.isValid,
              let weekday = Weekday(rawValue: calendar.component(.weekday, from: date)),
              schedule.days.contains(weekday) else { return nil }
        let day = calendar.startOfDay(for: date)
        guard let start = calendar.date(bySettingHour: schedule.start.hour, minute: schedule.start.minute, second: 0, of: day),
              let end = calendar.date(bySettingHour: schedule.end.hour, minute: schedule.end.minute, second: 0, of: day)
        else { return nil }
        return (start, end)
    }
}
