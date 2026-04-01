import XCTest
@testable import CCStatsOSX

final class KeychainCredentialsTests: XCTestCase {

    // MARK: - OAuthTokens.isExpired

    func testTokenNotExpired() {
        // Expires 1 hour from now
        let futureMs = Int64(Date().timeIntervalSince1970 * 1000) + 3_600_000
        let tokens = OAuthTokens(
            accessToken: "test-access",
            refreshToken: "test-refresh",
            expiresAt: futureMs,
            scopes: ["user:profile"],
            subscriptionType: "pro",
            rateLimitTier: "tier1"
        )
        XCTAssertFalse(tokens.isExpired)
    }

    func testTokenExpired() {
        // Expired 1 hour ago
        let pastMs = Int64(Date().timeIntervalSince1970 * 1000) - 3_600_000
        let tokens = OAuthTokens(
            accessToken: "test-access",
            refreshToken: "test-refresh",
            expiresAt: pastMs,
            scopes: nil,
            subscriptionType: nil,
            rateLimitTier: nil
        )
        XCTAssertTrue(tokens.isExpired)
    }

    func testTokenExpiredWithinBuffer() {
        // Expires in 4 minutes — within the 5-minute buffer, so should be considered expired
        let soonMs = Int64(Date().timeIntervalSince1970 * 1000) + 4 * 60 * 1000
        let tokens = OAuthTokens(
            accessToken: "test-access",
            refreshToken: "test-refresh",
            expiresAt: soonMs,
            scopes: nil,
            subscriptionType: nil,
            rateLimitTier: nil
        )
        XCTAssertTrue(tokens.isExpired)
    }

    func testTokenNotExpiredJustOutsideBuffer() {
        // Expires in 6 minutes — outside the 5-minute buffer
        let soonMs = Int64(Date().timeIntervalSince1970 * 1000) + 6 * 60 * 1000
        let tokens = OAuthTokens(
            accessToken: "test-access",
            refreshToken: "test-refresh",
            expiresAt: soonMs,
            scopes: nil,
            subscriptionType: nil,
            rateLimitTier: nil
        )
        XCTAssertFalse(tokens.isExpired)
    }

    // MARK: - OAuthTokens decoding

    func testOAuthTokensDecoding() throws {
        let json = """
        {
            "accessToken": "acc123",
            "refreshToken": "ref456",
            "expiresAt": 1718456400000,
            "scopes": ["user:profile", "user:inference"],
            "subscriptionType": "pro",
            "rateLimitTier": "tier4"
        }
        """
        let data = json.data(using: .utf8)!
        let tokens = try JSONDecoder().decode(OAuthTokens.self, from: data)
        XCTAssertEqual(tokens.accessToken, "acc123")
        XCTAssertEqual(tokens.refreshToken, "ref456")
        XCTAssertEqual(tokens.expiresAt, 1718456400000)
        XCTAssertEqual(tokens.scopes, ["user:profile", "user:inference"])
        XCTAssertEqual(tokens.subscriptionType, "pro")
        XCTAssertEqual(tokens.rateLimitTier, "tier4")
    }

    func testOAuthTokensDecodingNullOptionals() throws {
        let json = """
        {
            "accessToken": "acc",
            "refreshToken": "ref",
            "expiresAt": 1000
        }
        """
        let data = json.data(using: .utf8)!
        let tokens = try JSONDecoder().decode(OAuthTokens.self, from: data)
        XCTAssertNil(tokens.scopes)
        XCTAssertNil(tokens.subscriptionType)
        XCTAssertNil(tokens.rateLimitTier)
    }

    // MARK: - KeychainCredentials decoding

    func testKeychainCredentialsDecoding() throws {
        let json = """
        {
            "claudeAiOauth": {
                "accessToken": "acc",
                "refreshToken": "ref",
                "expiresAt": 1718456400000,
                "scopes": null,
                "subscriptionType": null,
                "rateLimitTier": null
            },
            "organizationUuid": "org-uuid-123"
        }
        """
        let data = json.data(using: .utf8)!
        let creds = try JSONDecoder().decode(KeychainCredentials.self, from: data)
        XCTAssertEqual(creds.claudeAiOauth.accessToken, "acc")
        XCTAssertEqual(creds.organizationUuid, "org-uuid-123")
    }

    // MARK: - KeychainCredentials roundtrip

    func testKeychainCredentialsRoundtrip() throws {
        let original = KeychainCredentials(
            claudeAiOauth: OAuthTokens(
                accessToken: "a",
                refreshToken: "r",
                expiresAt: 999999,
                scopes: ["scope1"],
                subscriptionType: "max",
                rateLimitTier: "tier5"
            ),
            organizationUuid: "org-1"
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeychainCredentials.self, from: encoded)

        XCTAssertEqual(decoded.claudeAiOauth.accessToken, "a")
        XCTAssertEqual(decoded.claudeAiOauth.refreshToken, "r")
        XCTAssertEqual(decoded.claudeAiOauth.expiresAt, 999999)
        XCTAssertEqual(decoded.claudeAiOauth.scopes, ["scope1"])
        XCTAssertEqual(decoded.claudeAiOauth.subscriptionType, "max")
        XCTAssertEqual(decoded.claudeAiOauth.rateLimitTier, "tier5")
        XCTAssertEqual(decoded.organizationUuid, "org-1")
    }
}
