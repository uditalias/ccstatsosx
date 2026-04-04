import Foundation

enum UsageAPIError: Error, LocalizedError {
    case httpError(Int, String?)
    case noData

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body):
            if let body { return "HTTP \(code): \(body)" }
            return "HTTP \(code)"
        case .noData:
            return "No data received"
        }
    }
}

struct UsageAPIService {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetchUsage() async throws -> UsageData {
        let (token, _) = try await AuthService.shared.getValidToken()

        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            NSLog("[API] No HTTP response object")
            throw UsageAPIError.httpError(0, "No HTTP response")
        }

        let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
        NSLog("[API] HTTP %d (%d bytes) Retry-After=%@", httpResponse.statusCode, data.count, retryAfter ?? "none")

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            NSLog("[API] Error body: %@", body ?? "(nil)")
            throw UsageAPIError.httpError(httpResponse.statusCode, body)
        }

        return try JSONDecoder().decode(UsageData.self, from: data)
    }
}
