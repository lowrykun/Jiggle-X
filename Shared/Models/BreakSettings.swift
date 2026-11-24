import Foundation

/// Random "offline" breaks: after Jiggle-X has kept you Available for `afterMinutes`
/// with no real input from you, it stops jiggling for a random 1…`maxBreakMinutes`
/// minutes so Teams can show you Away for a while.
struct BreakSettings: Codable, Equatable {
    var isEnabled: Bool
    /// Minutes without real input (while jiggling) before a break starts.
    var afterMinutes: Int
    /// Upper bound of the random break length, in minutes (lower bound is 1).
    var maxBreakMinutes: Int

    static let `default` = BreakSettings(isEnabled: false, afterMinutes: 15, maxBreakMinutes: 15)

    static let afterMinutesRange: ClosedRange<Int> = 5...120
    static let maxBreakMinutesRange: ClosedRange<Int> = 1...60

    /// Clamps both values into their allowed ranges.
    var clamped: BreakSettings {
        var s = self
        s.afterMinutes = min(max(afterMinutes, Self.afterMinutesRange.lowerBound), Self.afterMinutesRange.upperBound)
        s.maxBreakMinutes = min(max(maxBreakMinutes, Self.maxBreakMinutesRange.lowerBound),
                                Self.maxBreakMinutesRange.upperBound)
        return s
    }

    /// The range a break's length (in seconds) is drawn from.
    var breakDurationRange: ClosedRange<TimeInterval> {
        60...TimeInterval(maxBreakMinutes * 60)
    }
}
