import XCTest
@testable import CCStatsOSX

final class AuthServiceTokenTests: XCTestCase {

    // MARK: - Token expiry with realistic scenarios

    func testTokenExpiresAfterSleep() {
        // Simulate: token was valid, then hours pass (sleep)
        // Token expires in 1 hour, but we "slept" for 3 hours
        let issuedAt = Date().addingTimeInterval(-3 * 3600) // 3 hours ago
        let expiresAt = issuedAt.addingTimeInterval(3600) // was valid for 1 hour after issue
        let expiresAtMs = Int64(expiresAt.timeIntervalSince1970 * 1000)

        let tokens = OAuthTokens(
            accessToken: "old-access",
            refreshToken: "still-valid-refresh",
            expiresAt: expiresAtMs,
            scopes: nil,
            subscriptionType: nil,
            rateLimitTier: nil
        )

        XCTAssertTrue(tokens.isExpired, "Token should be expired after 3-hour sleep")
    }

    func testTokenStillValidDuringShortSleep() {
        // Token expires in 2 hours, sleep for 30 minutes
        let expiresAt = Date().addingTimeInterval(2 * 3600) // 2 hours from now
        let expiresAtMs = Int64(expiresAt.timeIntervalSince1970 * 1000)

        let tokens = OAuthTokens(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: expiresAtMs,
            scopes: nil,
            subscriptionType: nil,
            rateLimitTier: nil
        )

        XCTAssertFalse(tokens.isExpired, "Token should still be valid during short sleep")
    }

    func testTokenExpiryBufferPreventsLastMinuteExpiry() {
        // Token expires in exactly 5 minutes (the buffer window)
        let expiresAtMs = Int64(Date().timeIntervalSince1970 * 1000) + 5 * 60 * 1000

        let tokens = OAuthTokens(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: expiresAtMs,
            scopes: nil,
            subscriptionType: nil,
            rateLimitTier: nil
        )

        // Should be considered expired because 5 min buffer
        XCTAssertTrue(tokens.isExpired, "Token at exactly the buffer boundary should be considered expired")
    }

    // MARK: - TokenRefreshResponse creates valid OAuthTokens

    func testRefreshResponseCreatesValidTokens() throws {
        let json = """
        {
            "access_token": "new-access-token-abc123",
            "refresh_token": "new-refresh-token-xyz789",
            "expires_in": 7200,
            "token_type": "Bearer",
            "scope": "user:profile"
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)

        // Simulate creating new OAuthTokens from refresh response
        let expiresAt = Int64(Date().timeIntervalSince1970 * 1000) + Int64(response.expiresIn * 1000)

        let newTokens = OAuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: expiresAt,
            scopes: nil,
            subscriptionType: "pro",
            rateLimitTier: "tier4"
        )

        XCTAssertEqual(newTokens.accessToken, "new-access-token-abc123")
        XCTAssertEqual(newTokens.refreshToken, "new-refresh-token-xyz789")
        XCTAssertFalse(newTokens.isExpired, "Freshly created token should not be expired")
    }

    // MARK: - Credentials survive in memory after Keychain failure

    func testCredentialsRoundtripPreservesAllFields() throws {
        let original = KeychainCredentials(
            claudeAiOauth: OAuthTokens(
                accessToken: "access-123",
                refreshToken: "refresh-456",
                expiresAt: Int64(Date().timeIntervalSince1970 * 1000) + 3_600_000,
                scopes: ["user:profile", "user:inference"],
                subscriptionType: "max",
                rateLimitTier: "tier5"
            ),
            organizationUuid: "org-uuid-789"
        )

        // Simulate: encode → decode (as would happen in Keychain save/read)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeychainCredentials.self, from: encoded)

        XCTAssertEqual(decoded.claudeAiOauth.accessToken, original.claudeAiOauth.accessToken)
        XCTAssertEqual(decoded.claudeAiOauth.refreshToken, original.claudeAiOauth.refreshToken)
        XCTAssertEqual(decoded.claudeAiOauth.expiresAt, original.claudeAiOauth.expiresAt)
        XCTAssertEqual(decoded.claudeAiOauth.scopes, original.claudeAiOauth.scopes)
        XCTAssertEqual(decoded.claudeAiOauth.subscriptionType, original.claudeAiOauth.subscriptionType)
        XCTAssertEqual(decoded.claudeAiOauth.rateLimitTier, original.claudeAiOauth.rateLimitTier)
        XCTAssertEqual(decoded.organizationUuid, original.organizationUuid)
        XCTAssertFalse(decoded.claudeAiOauth.isExpired)
    }

    // MARK: - AuthError descriptions

    func testAuthErrorNoCredentials() {
        let error = AuthError.noCredentials
        XCTAssertNotNil(error as Error)
    }

    func testAuthErrorRefreshFailed() {
        let error = AuthError.refreshFailed("HTTP 401")
        if case .refreshFailed(let msg) = error {
            XCTAssertEqual(msg, "HTTP 401")
        } else {
            XCTFail("Expected refreshFailed")
        }
    }

    func testAuthErrorInvalidResponse() {
        let error = AuthError.invalidResponse
        XCTAssertNotNil(error as Error)
    }

    // MARK: - KeychainError descriptions

    func testKeychainErrorItemNotFound() {
        let error = KeychainError.itemNotFound
        XCTAssertNotNil(error as Error)
    }

    func testKeychainErrorUnexpectedData() {
        let error = KeychainError.unexpectedData
        XCTAssertNotNil(error as Error)
    }

    func testKeychainErrorOsError() {
        let error = KeychainError.osError(-25300)
        if case .osError(let status) = error {
            XCTAssertEqual(status, -25300)
        } else {
            XCTFail("Expected osError")
        }
    }
}
