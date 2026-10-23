import XCTest
@testable import JiggleX

final class FirstLaunchTests: XCTestCase {
    func testFirstLaunchShowsSettingsOnce() {
        let persistence = PersistenceManager(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        XCTAssertTrue(FirstLaunch.shouldShowSettings(persistence))
        FirstLaunch.markLaunched(persistence)
        XCTAssertFalse(FirstLaunch.shouldShowSettings(persistence))
    }
}
