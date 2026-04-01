import Foundation

enum AuthError: Error {
    case noCredentials
    case refreshFailed(String)
    case invalidResponse
}

struct TokenRefreshResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
    }
}

actor AuthService {
    static let shared = AuthService()

    private let clientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private let tokenURL = URL(string: "https://platform.claude.com/v1/oauth/token")!
    private let defaultScopes = "user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload"
    private var isRefreshing = false
    private var cachedCredentials: KeychainCredentials?
    private var hasLoadedFromKeychain = false

    /// Load credentials from Keychain exactly once. Call this at app startup.
    func loadCredentials() throws {
        guard !hasLoadedFromKeychain else { return }
        cachedCredentials = try KeychainService.readCredentials()
        hasLoadedFromKeychain = true
    }

    /// Force re-read credentials from Keychain. Use after auth errors
    /// or wake from sleep when Keychain state may have changed.
    func reloadCredentials() throws {
        cachedCredentials = try KeychainService.readCredentials()
        hasLoadedFromKeychain = true
    }

    func getValidToken() async throws -> (token: String, credentials: KeychainCredentials) {
        // Ensure we've loaded from Keychain
        if !hasLoadedFromKeychain {
            try loadCredentials()
        }

        guard var credentials = cachedCredentials else {
            throw AuthError.noCredentials
        }

        if credentials.claudeAiOauth.isExpired {
            credentials = try await refreshToken(credentials)
            cachedCredentials = credentials
        }

        return (credentials.claudeAiOauth.accessToken, credentials)
    }

    func getCachedCredentials() -> KeychainCredentials? {
        return cachedCredentials
    }

    private func refreshToken(_ credentials: KeychainCredentials) async throws -> KeychainCredentials {
        guard !isRefreshing else {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            if let cached = cachedCredentials, !cached.claudeAiOauth.isExpired {
                return cached
            }
            throw AuthError.refreshFailed("Concurrent refresh failed")
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": credentials.claudeAiOauth.refreshToken,
            "client_id": clientId,
            "scope": defaultScopes
        ]

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AuthError.refreshFailed("HTTP \(statusCode)")
        }

        let tokenResponse = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
        let expiresAt = Int64(Date().timeIntervalSince1970 * 1000) + Int64(tokenResponse.expiresIn * 1000)

        let newOAuth = OAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: expiresAt,
            scopes: credentials.claudeAiOauth.scopes,
            subscriptionType: credentials.claudeAiOauth.subscriptionType,
            rateLimitTier: credentials.claudeAiOauth.rateLimitTier
        )

        let newCredentials = KeychainCredentials(
            claudeAiOauth: newOAuth,
            organizationUuid: credentials.organizationUuid
        )

        // Update in-memory cache first so the app keeps working
        // even if Keychain save fails (e.g. locked after sleep)
        cachedCredentials = newCredentials

        // Persist to Keychain (best-effort — may fail after wake)
        do {
            try KeychainService.saveCredentials(newCredentials)
        } catch {
            NSLog("[Auth] Keychain save failed (token still valid in memory): %@", "\(error)")
        }

        return newCredentials
    }
}
