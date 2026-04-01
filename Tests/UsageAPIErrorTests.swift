import XCTest
@testable import CCStatsOSX

final class UsageAPIErrorTests: XCTestCase {

    func testHttpErrorWithBody() {
        let error = UsageAPIError.httpError(429, "Rate limited")
        XCTAssertEqual(error.errorDescription, "HTTP 429: Rate limited")
    }

    func testHttpErrorWithoutBody() {
        let error = UsageAPIError.httpError(500, nil)
        XCTAssertEqual(error.errorDescription, "HTTP 500")
    }

    func testNoDataError() {
        let error = UsageAPIError.noData
        XCTAssertEqual(error.errorDescription, "No data received")
    }

    func testHttpErrorLocalizedDescription() {
        let error: Error = UsageAPIError.httpError(403, "Forbidden")
        XCTAssertEqual(error.localizedDescription, "HTTP 403: Forbidden")
    }
}
