import XCTest
@testable import CCStatsOSX

final class NotificationServiceTests: XCTestCase {

    // We test the notification tracking logic by checking the internal notifiedThresholds set.
    // Since NotificationService uses osascript for actual notifications, no real notifications
    // are sent during tests when utilization is below thresholds.

    private func makeUsageData(fiveHourUtil: Double? = nil, sevenDayUtil: Double? = nil) -> UsageData {
        return UsageData(
            fiveHour: fiveHourUtil.map { RateLimit(utilization: $0, resetsAt: nil) },
            sevenDay: sevenDayUtil.map { RateLimit(utilization: $0, resetsAt: nil) },
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            sevenDayOauthApps: nil,
            sevenDayCowork: nil,
            extraUsage: nil
        )
    }

    func testResetClearsThresholdsWhenBelowWarning() {
        let service = NotificationService()
        // Simulate: usage was high, thresholds were notified
        service.notifiedThresholds.insert("5h_warning")
        service.notifiedThresholds.insert("5h_critical")
        service.notifiedThresholds.insert("7d_warning")
        service.notifiedThresholds.insert("7d_critical")

        // Now usage drops below warning
        let data = makeUsageData(fiveHourUtil: 30, sevenDayUtil: 20)
        service.resetIfNeeded(data: data)

        XCTAssertFalse(service.notifiedThresholds.contains("5h_warning"))
        XCTAssertFalse(service.notifiedThresholds.contains("5h_critical"))
        XCTAssertFalse(service.notifiedThresholds.contains("7d_warning"))
        XCTAssertFalse(service.notifiedThresholds.contains("7d_critical"))
    }

    func testResetDoesNotClearWhenAboveWarning() {
        let service = NotificationService()
        service.notifiedThresholds.insert("5h_warning")

        // Usage is still above warning threshold (default 70%)
        let data = makeUsageData(fiveHourUtil: 75, sevenDayUtil: 10)
        service.resetIfNeeded(data: data)

        XCTAssertTrue(service.notifiedThresholds.contains("5h_warning"))
    }

    func testResetHandlesNilData() {
        let service = NotificationService()
        service.notifiedThresholds.insert("5h_warning")

        // No five_hour or seven_day data
        let data = makeUsageData()
        service.resetIfNeeded(data: data)

        // Should not crash, thresholds remain
        XCTAssertTrue(service.notifiedThresholds.contains("5h_warning"))
    }

    func testResetPartialData() {
        let service = NotificationService()
        service.notifiedThresholds.insert("5h_warning")
        service.notifiedThresholds.insert("7d_warning")

        // Only five_hour drops below, seven_day stays above
        let data = makeUsageData(fiveHourUtil: 30, sevenDayUtil: 80)
        service.resetIfNeeded(data: data)

        XCTAssertFalse(service.notifiedThresholds.contains("5h_warning"))
        XCTAssertTrue(service.notifiedThresholds.contains("7d_warning"))
    }
}
