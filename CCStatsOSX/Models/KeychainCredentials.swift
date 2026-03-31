import Foundation

struct OAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int64
    let scopes: [String]?
    let subscriptionType: String?
    let rateLimitTier: String?

    var isExpired: Bool {
        let bufferMs: Int64 = 5 * 60 * 1000
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return (now + bufferMs) >= expiresAt
    }
}

struct KeychainCredentials: Codable {
    let claudeAiOauth: OAuthTokens
    let organizationUuid: String
}
