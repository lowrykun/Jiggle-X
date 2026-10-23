import IOKit.pwr_mgt
import XCTest
@testable import JiggleX

final class PowerAssertionNudgerTests: XCTestCase {
    func testStaleAssertionIDIsDroppedAndRetried() {
        var receivedIDs: [IOPMAssertionID] = []
        let nudger = PowerAssertionNudger { id in
            receivedIDs.append(id)
            if id == 42 { return kIOReturnError } // stale ID from an earlier call
            id = 42
            return kIOReturnSuccess
        }
        XCTAssertTrue(nudger.declareActivity())   // null → 42
        XCTAssertTrue(nudger.declareActivity())   // 42 fails → retried with null → 42
        XCTAssertEqual(receivedIDs, [0, 42, 0])
    }

    func testReportsFailureWhenRetryAlsoFails() {
        let nudger = PowerAssertionNudger { _ in kIOReturnError }
        XCTAssertFalse(nudger.declareActivity())
    }
}
