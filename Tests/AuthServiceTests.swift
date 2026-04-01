import XCTest
@testable import CCStatsOSX

final class AuthServiceTests: XCTestCase {

    // MARK: - TokenRefreshResponse decoding

    func testTokenRefreshResponseDecoding() throws {
        let json = """
        {
            "access_token": "new-access-token",
            "refresh_token": "new-refresh-token",
            "expires_in": 3600,
            "token_type": "Bearer",
            "scope": "user:profile user:inference"
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

        XCTAssertEqual(response.accessToken, "new-access-token")
        XCTAssertEqual(response.refreshToken, "new-refresh-token")
        XCTAssertEqual(response.expiresIn, 3600)
        XCTAssertEqual(response.tokenType, "Bearer")
        XCTAssertEqual(response.scope, "user:profile user:inference")
    }

    func testTokenRefreshResponseDecodingMinimal() throws {
        let json = """
        {
            "access_token": "tok",
            "refresh_token": "ref",
            "expires_in": 1800
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

        XCTAssertEqual(response.accessToken, "tok")
        XCTAssertEqual(response.refreshToken, "ref")
        XCTAssertEqual(response.expiresIn, 1800)
        XCTAssertNil(response.tokenType)
        XCTAssertNil(response.scope)
    }

    // MARK: - AuthError

    func testAuthErrorCases() {
        // Verify error cases exist and can be created
        let noCredentials = AuthError.noCredentials
        let refreshFailed = AuthError.refreshFailed("HTTP 401")
        let invalidResponse = AuthError.invalidResponse

        // These should be Error-conforming
        XCTAssertNotNil(noCredentials as Error)
        XCTAssertNotNil(refreshFailed as Error)
        XCTAssertNotNil(invalidResponse as Error)
    }

    // MARK: - ConnectionState

    func testConnectionStateConnected() {
        let state = ConnectionState.connected
        if case .connected = state {
            // passes
        } else {
            XCTFail("Expected connected state")
        }
    }

    func testConnectionStateDisconnected() {
        let state = ConnectionState.disconnected("Claude Code not found")
        if case .disconnected(let reason) = state {
            XCTAssertEqual(reason, "Claude Code not found")
        } else {
            XCTFail("Expected disconnected state")
        }
    }

    func testConnectionStateError() {
        let state = ConnectionState.error("Auth: refresh failed")
        if case .error(let msg) = state {
            XCTAssertEqual(msg, "Auth: refresh failed")
        } else {
            XCTFail("Expected error state")
        }
    }
}
