import XCTest
@testable import JiggleX

final class SmokeTests: XCTestCase {
    func testBundleIdentifier() {
        XCTAssertEqual(Constants.bundleIdentifier, "com.jasonlowry.JiggleX")
    }
}
