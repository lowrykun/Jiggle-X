import Foundation

/// What Jiggle-X is doing right now.
enum RunState: Equatable {
    /// In a working window and not paused: declaring activity whenever the user goes idle.
    case active
    /// Paused until the user clicks Resume.
    case paused
    /// "Pause Until Tomorrow": resumes at the given window start.
    case pausedUntil(Date)
    /// Not in a working window.
    case outsideHours
}
