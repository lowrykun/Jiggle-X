import Foundation

/// Gregorian calendar pinned to America/New_York so DST tests are deterministic.
let newYorkCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York")!
    calendar.locale = Locale(identifier: "en_US")
    return calendar
}()

/// A local wall-clock date in `newYorkCalendar`.
func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    newYorkCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}
