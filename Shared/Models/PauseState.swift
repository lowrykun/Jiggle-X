import Foundation

/// The user's manual override, persisted so a relaunch doesn't surprise-resume.
enum PauseState: Codable, Equatable {
    case none
    /// Paused until the user clicks Resume.
    case paused
    /// "Pause Until Tomorrow": clears automatically at `resumeAt` (the next window start).
    case untilNextWindow(resumeAt: Date)
}
