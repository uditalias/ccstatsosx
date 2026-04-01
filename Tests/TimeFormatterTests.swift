import XCTest
@testable import CCStatsOSX

final class TimeFormatterTests: XCTestCase {

    // MARK: - countdown(to:from:)

    func testCountdownHoursAndMinutes() {
        let now = Date()
        let future = now.addingTimeInterval(2 * 3600 + 14 * 60) // 2h 14m
        XCTAssertEqual(TimeFormatter.countdown(to: future, from: now), "2h 14m")
    }

    func testCountdownExactHours() {
        let now = Date()
        let future = now.addingTimeInterval(3 * 3600) // 3h 0m
        XCTAssertEqual(TimeFormatter.countdown(to: future, from: now), "3h 0m")
    }

    func testCountdownMinutesOnly() {
        let now = Date()
        let future = now.addingTimeInterval(45 * 60) // 45m
        XCTAssertEqual(TimeFormatter.countdown(to: future, from: now), "45m")
    }

    func testCountdownSecondsOnly() {
        let now = Date()
        let future = now.addingTimeInterval(30) // 30s
        XCTAssertEqual(TimeFormatter.countdown(to: future, from: now), "30s")
    }

    func testCountdownOneSecond() {
        let now = Date()
        let future = now.addingTimeInterval(1)
        XCTAssertEqual(TimeFormatter.countdown(to: future, from: now), "1s")
    }

    func testCountdownPastDateReturnsNow() {
        let now = Date()
        let past = now.addingTimeInterval(-60)
        XCTAssertEqual(TimeFormatter.countdown(to: past, from: now), "now")
    }

    func testCountdownExactlyNowReturnsNow() {
        let now = Date()
        XCTAssertEqual(TimeFormatter.countdown(to: now, from: now), "now")
    }

    func testCountdownOneMinuteZeroSeconds() {
        let now = Date()
        let future = now.addingTimeInterval(60)
        XCTAssertEqual(TimeFormatter.countdown(to: future, from: now), "1m")
    }

    // MARK: - resetDate(_:)

    func testResetDateToday() {
        let calendar = Calendar.current
        // Create a date today at 4:00 PM
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 16
        components.minute = 0
        let date = calendar.date(from: components)!

        let result = TimeFormatter.resetDate(date)
        // Should show time only, e.g. "4:00 PM"
        XCTAssertTrue(result.contains("4:00"), "Expected time format, got: \(result)")
        XCTAssertTrue(result.contains("PM"), "Expected PM, got: \(result)")
        XCTAssertFalse(result.contains("Tomorrow"), "Should not contain Tomorrow for today's date")
    }

    func testResetDateTomorrow() {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 14
        components.minute = 30
        let date = calendar.date(from: components)!

        let result = TimeFormatter.resetDate(date)
        XCTAssertTrue(result.contains("Tomorrow"), "Expected 'Tomorrow', got: \(result)")
        XCTAssertTrue(result.contains("2:30"), "Expected time, got: \(result)")
    }

    func testResetDateFutureDay() {
        let calendar = Calendar.current
        // 5 days from now — should show weekday name
        let futureDate = calendar.date(byAdding: .day, value: 5, to: Date())!
        var components = calendar.dateComponents([.year, .month, .day], from: futureDate)
        components.hour = 10
        components.minute = 0
        let date = calendar.date(from: components)!

        let result = TimeFormatter.resetDate(date)
        // Should contain a weekday abbreviation (Mon, Tue, etc.)
        let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let containsWeekday = weekdays.contains { result.contains($0) }
        XCTAssertTrue(containsWeekday, "Expected weekday abbreviation, got: \(result)")
    }

    // MARK: - timeSince(_:from:)

    func testTimeSinceSeconds() {
        let now = Date()
        let past = now.addingTimeInterval(-30)
        XCTAssertEqual(TimeFormatter.timeSince(past, from: now), "30s ago")
    }

    func testTimeSinceMinutes() {
        let now = Date()
        let past = now.addingTimeInterval(-5 * 60)
        XCTAssertEqual(TimeFormatter.timeSince(past, from: now), "5m ago")
    }

    func testTimeSinceHours() {
        let now = Date()
        let past = now.addingTimeInterval(-2 * 3600)
        XCTAssertEqual(TimeFormatter.timeSince(past, from: now), "2h ago")
    }

    func testTimeSinceJustNow() {
        let now = Date()
        XCTAssertEqual(TimeFormatter.timeSince(now, from: now), "0s ago")
    }

    func testTimeSinceBoundary59Seconds() {
        let now = Date()
        let past = now.addingTimeInterval(-59)
        XCTAssertEqual(TimeFormatter.timeSince(past, from: now), "59s ago")
    }

    func testTimeSinceBoundary60Seconds() {
        let now = Date()
        let past = now.addingTimeInterval(-60)
        XCTAssertEqual(TimeFormatter.timeSince(past, from: now), "1m ago")
    }

    func testTimeSinceBoundary3599Seconds() {
        let now = Date()
        let past = now.addingTimeInterval(-3599)
        XCTAssertEqual(TimeFormatter.timeSince(past, from: now), "59m ago")
    }

    func testTimeSinceBoundary3600Seconds() {
        let now = Date()
        let past = now.addingTimeInterval(-3600)
        XCTAssertEqual(TimeFormatter.timeSince(past, from: now), "1h ago")
    }
}
