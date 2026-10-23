import Foundation

/// UserDefaults-backed settings. Reads never fail: anything missing, corrupt or
/// invalid falls back to a safe default.
final class PersistenceManager {
    static let shared = PersistenceManager(defaults: .standard)

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    var schedule: Schedule {
        get {
            guard var schedule = decode(Schedule.self, forKey: Constants.Keys.schedule), schedule.isValid else {
                return .default
            }
            let range = Schedule.idleThresholdRange
            schedule.idleThreshold = min(max(schedule.idleThreshold, range.lowerBound), range.upperBound)
            return schedule
        }
        set { encode(newValue, forKey: Constants.Keys.schedule) }
    }

    var pauseState: PauseState {
        get { decode(PauseState.self, forKey: Constants.Keys.pauseState) ?? .none }
        set { encode(newValue, forKey: Constants.Keys.pauseState) }
    }

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Constants.Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Constants.Keys.hasLaunchedBefore) }
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
