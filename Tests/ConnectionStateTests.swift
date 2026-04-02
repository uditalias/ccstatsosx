import XCTest
@testable import CCStatsOSX

final class ConnectionStateTests: XCTestCase {

    // MARK: - Equatable conformance

    func testConnectedEquality() {
        XCTAssertEqual(ConnectionState.connected, ConnectionState.connected)
    }

    func testDisconnectedEquality() {
        XCTAssertEqual(
            ConnectionState.disconnected("Starting..."),
            ConnectionState.disconnected("Starting...")
        )
    }

    func testDisconnectedInequality() {
        XCTAssertNotEqual(
            ConnectionState.disconnected("Starting..."),
            ConnectionState.disconnected("Reconnecting...")
        )
    }

    func testErrorEquality() {
        XCTAssertEqual(
            ConnectionState.error("Auth: refresh failed"),
            ConnectionState.error("Auth: refresh failed")
        )
    }

    func testDifferentCasesNotEqual() {
        XCTAssertNotEqual(ConnectionState.connected, ConnectionState.disconnected("x"))
        XCTAssertNotEqual(ConnectionState.connected, ConnectionState.error("x"))
        XCTAssertNotEqual(ConnectionState.disconnected("x"), ConnectionState.error("x"))
    }

    // MARK: - State transitions (as used by the app)

    func testStartupState() {
        // App starts with disconnected "Starting..."
        let state: ConnectionState = .disconnected("Starting...")
        XCTAssertEqual(state, .disconnected("Starting..."))
    }

    func testReconnectingState() {
        // Wake sets "Reconnecting..."
        let state: ConnectionState = .disconnected("Reconnecting...")
        XCTAssertEqual(state, .disconnected("Reconnecting..."))
    }

    func testClaudeCodeNotFoundState() {
        // Keychain error
        let state: ConnectionState = .disconnected("Claude Code not found")
        XCTAssertEqual(state, .disconnected("Claude Code not found"))
    }

    func testRateLimitedState() {
        let state: ConnectionState = .error("Rate limited — retrying soon")
        XCTAssertEqual(state, .error("Rate limited — retrying soon"))
    }
}
