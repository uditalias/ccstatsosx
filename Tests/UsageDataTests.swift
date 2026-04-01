import XCTest
@testable import CCStatsOSX

final class UsageDataTests: XCTestCase {

    // MARK: - RateLimit decoding

    func testRateLimitDecodingFull() throws {
        let json = """
        {
            "utilization": 45.5,
            "resets_at": "2025-06-15T14:30:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let rateLimit = try JSONDecoder().decode(RateLimit.self, from: data)
        XCTAssertEqual(rateLimit.utilization, 45.5)
        XCTAssertEqual(rateLimit.resetsAt, "2025-06-15T14:30:00Z")
    }

    func testRateLimitDecodingNullFields() throws {
        let json = """
        {
            "utilization": null,
            "resets_at": null
        }
        """
        let data = json.data(using: .utf8)!
        let rateLimit = try JSONDecoder().decode(RateLimit.self, from: data)
        XCTAssertNil(rateLimit.utilization)
        XCTAssertNil(rateLimit.resetsAt)
    }

    func testRateLimitDecodingMissingFields() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let rateLimit = try JSONDecoder().decode(RateLimit.self, from: data)
        XCTAssertNil(rateLimit.utilization)
        XCTAssertNil(rateLimit.resetsAt)
    }

    // MARK: - RateLimit.resetsAtDate

    func testResetsAtDateWithFractionalSeconds() {
        let rateLimit = RateLimit(utilization: 50, resetsAt: "2025-06-15T14:30:00.123Z")
        let date = rateLimit.resetsAtDate
        XCTAssertNotNil(date)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date!)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }

    func testResetsAtDateWithoutFractionalSeconds() {
        let rateLimit = RateLimit(utilization: 50, resetsAt: "2025-06-15T14:30:00Z")
        let date = rateLimit.resetsAtDate
        XCTAssertNotNil(date)
    }

    func testResetsAtDateNilWhenNoResetsAt() {
        let rateLimit = RateLimit(utilization: 50, resetsAt: nil)
        XCTAssertNil(rateLimit.resetsAtDate)
    }

    func testResetsAtDateWithTimezoneOffset() {
        let rateLimit = RateLimit(utilization: 50, resetsAt: "2025-06-15T14:30:00+05:00")
        let date = rateLimit.resetsAtDate
        XCTAssertNotNil(date)
    }

    // MARK: - ExtraUsage decoding

    func testExtraUsageDecodingFull() throws {
        let json = """
        {
            "is_enabled": true,
            "monthly_limit": 100.0,
            "used_credits": 25.5,
            "utilization": 25.5
        }
        """
        let data = json.data(using: .utf8)!
        let extra = try JSONDecoder().decode(ExtraUsage.self, from: data)
        XCTAssertEqual(extra.isEnabled, true)
        XCTAssertEqual(extra.monthlyLimit, 100.0)
        XCTAssertEqual(extra.usedCredits, 25.5)
        XCTAssertEqual(extra.utilization, 25.5)
    }

    func testExtraUsageDecodingDisabled() throws {
        let json = """
        {
            "is_enabled": false,
            "monthly_limit": null,
            "used_credits": null,
            "utilization": null
        }
        """
        let data = json.data(using: .utf8)!
        let extra = try JSONDecoder().decode(ExtraUsage.self, from: data)
        XCTAssertEqual(extra.isEnabled, false)
        XCTAssertNil(extra.monthlyLimit)
        XCTAssertNil(extra.usedCredits)
        XCTAssertNil(extra.utilization)
    }

    // MARK: - UsageData decoding

    func testUsageDataFullDecoding() throws {
        let json = """
        {
            "five_hour": {"utilization": 45.0, "resets_at": "2025-06-15T14:30:00Z"},
            "seven_day": {"utilization": 12.0, "resets_at": "2025-06-20T00:00:00Z"},
            "seven_day_sonnet": {"utilization": 5.0, "resets_at": "2025-06-20T00:00:00Z"},
            "seven_day_opus": {"utilization": 8.0, "resets_at": "2025-06-20T00:00:00Z"},
            "seven_day_oauth_apps": null,
            "seven_day_cowork": {"utilization": 3.0, "resets_at": "2025-06-20T00:00:00Z"},
            "extra_usage": {"is_enabled": false, "monthly_limit": null, "used_credits": null, "utilization": null}
        }
        """
        let data = json.data(using: .utf8)!
        let usage = try JSONDecoder().decode(UsageData.self, from: data)

        XCTAssertEqual(usage.fiveHour?.utilization, 45.0)
        XCTAssertEqual(usage.sevenDay?.utilization, 12.0)
        XCTAssertEqual(usage.sevenDaySonnet?.utilization, 5.0)
        XCTAssertEqual(usage.sevenDayOpus?.utilization, 8.0)
        XCTAssertNil(usage.sevenDayOauthApps)
        XCTAssertEqual(usage.sevenDayCowork?.utilization, 3.0)
        XCTAssertEqual(usage.extraUsage?.isEnabled, false)
    }

    func testUsageDataMinimalDecoding() throws {
        let json = """
        {
            "five_hour": {"utilization": 10.0, "resets_at": "2025-06-15T14:30:00Z"},
            "seven_day": {"utilization": 5.0, "resets_at": "2025-06-20T00:00:00Z"}
        }
        """
        let data = json.data(using: .utf8)!
        let usage = try JSONDecoder().decode(UsageData.self, from: data)

        XCTAssertEqual(usage.fiveHour?.utilization, 10.0)
        XCTAssertEqual(usage.sevenDay?.utilization, 5.0)
        XCTAssertNil(usage.sevenDaySonnet)
        XCTAssertNil(usage.sevenDayOpus)
        XCTAssertNil(usage.sevenDayOauthApps)
        XCTAssertNil(usage.sevenDayCowork)
        XCTAssertNil(usage.extraUsage)
    }

    func testUsageDataEmptyDecoding() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let usage = try JSONDecoder().decode(UsageData.self, from: data)

        XCTAssertNil(usage.fiveHour)
        XCTAssertNil(usage.sevenDay)
    }

    // MARK: - UsageData encoding roundtrip

    func testUsageDataRoundtrip() throws {
        let original = UsageData(
            fiveHour: RateLimit(utilization: 55.5, resetsAt: "2025-06-15T14:30:00Z"),
            sevenDay: RateLimit(utilization: 22.0, resetsAt: "2025-06-20T00:00:00Z"),
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            sevenDayOauthApps: nil,
            sevenDayCowork: nil,
            extraUsage: nil
        )

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UsageData.self, from: encoded)

        XCTAssertEqual(decoded.fiveHour?.utilization, 55.5)
        XCTAssertEqual(decoded.sevenDay?.utilization, 22.0)
        XCTAssertEqual(decoded.fiveHour?.resetsAt, "2025-06-15T14:30:00Z")
    }
}
