import Foundation

/// On the very first launch, Settings opens so the user sees the schedule
/// Jiggle-X is already running on.
enum FirstLaunch {
    static func shouldShowSettings(_ persistence: PersistenceManager) -> Bool {
        !persistence.hasLaunchedBefore
    }

    static func markLaunched(_ persistence: PersistenceManager) {
        persistence.hasLaunchedBefore = true
    }
}
