import Foundation

#if DEBUG
struct MockUsageService {
    static func fetchUsage() -> UsageData {
        return UsageData(
            fiveHour: RateLimit(
                utilization: 45,
                resetsAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 2 + 780)) // ~2h 13m from now
            ),
            sevenDay: RateLimit(
                utilization: 12,
                resetsAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 24 * 3)) // 3 days from now
            ),
            sevenDaySonnet: RateLimit(
                utilization: 5,
                resetsAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600 * 24 * 2))
            ),
            sevenDayOpus: nil,
            sevenDayOauthApps: nil,
            sevenDayCowork: nil,
            extraUsage: ExtraUsage(
                isEnabled: false,
                monthlyLimit: nil,
                usedCredits: nil,
                utilization: nil
            )
        )
    }
}
#endif
