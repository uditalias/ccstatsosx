import XCTest
@testable import CCStatsOSX

@MainActor
final class PollSchedulerTests: XCTestCase {

    // MARK: - Helpers

    private func makeUsageData(fiveHourUtil: Double = 30, sevenDayUtil: Double = 10) -> UsageData {
        UsageData(
            fiveHour: RateLimit(utilization: fiveHourUtil, resetsAt: nil),
            sevenDay: RateLimit(utilization: sevenDayUtil, resetsAt: nil),
            sevenDaySonnet: nil,
            sevenDayOpus: nil,
            sevenDayOauthApps: nil,
            sevenDayCowork: nil,
            extraUsage: nil
        )
    }

    private func makeScheduler(fetcher: @escaping () async throws -> UsageData) -> PollScheduler {
        let scheduler = PollScheduler()
        scheduler.usageFetcher = fetcher
        return scheduler
    }

    // MARK: - Successful poll

    func testPollSuccessSetsConnectedState() async {
        let data = makeUsageData()
        let scheduler = makeScheduler { data }

        await scheduler.poll()

        XCTAssertEqual(scheduler.connectionState, .connected)
        XCTAssertNotNil(scheduler.usageData)
        XCTAssertEqual(scheduler.usageData?.fiveHour?.utilization, 30)
        XCTAssertNotNil(scheduler.lastUpdated)
        XCTAssertNotNil(scheduler.lastPollTime)
        XCTAssertEqual(scheduler.errorCount, 0)
    }

    func testPollSuccessResetsErrorCount() async {
        let data = makeUsageData()
        let scheduler = makeScheduler { data }

        // Simulate previous errors
        await scheduler.poll() // success
        scheduler.usageFetcher = { throw AuthError.noCredentials }
        await scheduler.poll() // error
        await scheduler.poll() // error
        XCTAssertEqual(scheduler.errorCount, 2)

        // Now succeed
        scheduler.usageFetcher = { data }
        await scheduler.poll()
        XCTAssertEqual(scheduler.errorCount, 0)
        XCTAssertEqual(scheduler.connectionState, .connected)
    }

    // MARK: - Error handling

    func testPollKeychainErrorSetsDisconnected() async {
        let scheduler = makeScheduler { throw KeychainError.itemNotFound }

        await scheduler.poll()

        XCTAssertEqual(scheduler.connectionState, .disconnected("Claude Code not found"))
        XCTAssertEqual(scheduler.errorCount, 1)
        XCTAssertNil(scheduler.usageData)
    }

    func testPollAuthErrorSetsErrorState() async {
        let scheduler = makeScheduler { throw AuthError.refreshFailed("HTTP 401") }

        await scheduler.poll()

        if case .error(let msg) = scheduler.connectionState {
            XCTAssertTrue(msg.contains("Auth"), "Expected auth error, got: \(msg)")
        } else {
            XCTFail("Expected error state, got: \(scheduler.connectionState)")
        }
        XCTAssertEqual(scheduler.errorCount, 1)
    }

    func testPollRateLimitErrorShowsSpecificMessage() async {
        let scheduler = makeScheduler { throw UsageAPIError.httpError(429, "Too Many Requests") }

        await scheduler.poll()

        XCTAssertEqual(scheduler.connectionState, .error("Rate limited — retrying soon"))
        XCTAssertEqual(scheduler.errorCount, 1)
    }

    func testPollGenericAPIErrorShowsDescription() async {
        let scheduler = makeScheduler { throw UsageAPIError.httpError(500, "Internal Server Error") }

        await scheduler.poll()

        if case .error(let msg) = scheduler.connectionState {
            XCTAssertTrue(msg.contains("500"), "Expected HTTP 500 in error, got: \(msg)")
        } else {
            XCTFail("Expected error state")
        }
    }

    func testPollNoDataErrorShowsDescription() async {
        let scheduler = makeScheduler { throw UsageAPIError.noData }

        await scheduler.poll()

        if case .error(let msg) = scheduler.connectionState {
            XCTAssertTrue(msg.contains("No data"), "Expected 'No data' error, got: \(msg)")
        } else {
            XCTFail("Expected error state")
        }
    }

    func testPollGenericErrorShowsDescription() async {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Something went wrong" }
        }
        let scheduler = makeScheduler { throw TestError() }

        await scheduler.poll()

        if case .error(let msg) = scheduler.connectionState {
            XCTAssertTrue(msg.contains("Something went wrong"), "Got: \(msg)")
        } else {
            XCTFail("Expected error state")
        }
    }

    func testErrorCountIncrements() async {
        let scheduler = makeScheduler { throw AuthError.noCredentials }

        await scheduler.poll()
        XCTAssertEqual(scheduler.errorCount, 1)

        await scheduler.poll()
        XCTAssertEqual(scheduler.errorCount, 2)

        await scheduler.poll()
        XCTAssertEqual(scheduler.errorCount, 3)
    }

    // MARK: - start() resets state

    func testStartResetsErrorCount() async {
        let scheduler = makeScheduler { throw AuthError.noCredentials }

        await scheduler.poll()
        await scheduler.poll()
        XCTAssertEqual(scheduler.errorCount, 2)

        // start() resets counts before polling
        scheduler.usageFetcher = { self.makeUsageData() }
        scheduler.start()
        // Give the Task in start() time to run
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(scheduler.errorCount, 0)
        XCTAssertEqual(scheduler.connectionState, .connected)
    }

    func testStartResetsUnchangedCount() async {
        let data = makeUsageData()
        let scheduler = makeScheduler { data }

        // Poll same data multiple times to build up unchangedCount
        await scheduler.poll()
        await scheduler.poll()
        await scheduler.poll()
        XCTAssertEqual(scheduler.unchangedCount, 2) // first poll sets hash, next two are unchanged

        // Change to different data so the poll after start() doesn't count as unchanged
        scheduler.usageFetcher = { self.makeUsageData(fiveHourUtil: 99, sevenDayUtil: 99) }
        scheduler.start()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // start() resets to 0, then the new poll sees different data → still 0
        XCTAssertEqual(scheduler.unchangedCount, 0)
    }

    func testStartStopsExistingTimer() async {
        let data = makeUsageData()
        let scheduler = makeScheduler { data }

        await scheduler.poll() // sets a timer via scheduleNext
        XCTAssertNotNil(scheduler.timer)

        scheduler.stop()
        XCTAssertNil(scheduler.timer)
    }

    // MARK: - pollNow()

    func testPollNowBlockedWhilePolling() async {
        var callCount = 0
        let scheduler = makeScheduler {
            callCount += 1
            // Simulate slow network
            try await Task.sleep(nanoseconds: 200_000_000)
            return self.makeUsageData()
        }

        // Start a poll
        let task = Task { await scheduler.poll() }
        // Give it time to set isPolling
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertTrue(scheduler.isPolling)

        // pollNow should be blocked
        scheduler.pollNow()
        // Give it a moment
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Wait for original poll to finish
        await task.value

        // Only one poll should have run
        XCTAssertEqual(callCount, 1)
    }

    func testPollNowWorksWhenNotPolling() async {
        var callCount = 0
        let scheduler = makeScheduler {
            callCount += 1
            return self.makeUsageData()
        }

        scheduler.pollNow()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(scheduler.connectionState, .connected)
    }

    // MARK: - Concurrent poll prevention

    func testConcurrentPollPrevention() async {
        var callCount = 0
        let scheduler = makeScheduler {
            callCount += 1
            try await Task.sleep(nanoseconds: 100_000_000)
            return self.makeUsageData()
        }

        // Fire two polls simultaneously
        async let p1: Void = scheduler.poll()
        async let p2: Void = scheduler.poll()
        _ = await (p1, p2)

        // Only one should have executed
        XCTAssertEqual(callCount, 1)
    }

    // MARK: - Unchanged data tracking

    func testUnchangedCountIncrementsForSameData() async {
        let data = makeUsageData(fiveHourUtil: 50, sevenDayUtil: 20)
        let scheduler = makeScheduler { data }

        await scheduler.poll()
        XCTAssertEqual(scheduler.unchangedCount, 0) // first poll sets hash

        await scheduler.poll()
        XCTAssertEqual(scheduler.unchangedCount, 1)

        await scheduler.poll()
        XCTAssertEqual(scheduler.unchangedCount, 2)
    }

    func testUnchangedCountResetsWhenDataChanges() async {
        var util = 50.0
        let scheduler = makeScheduler {
            let data = self.makeUsageData(fiveHourUtil: util)
            return data
        }

        await scheduler.poll()
        await scheduler.poll()
        await scheduler.poll()
        XCTAssertEqual(scheduler.unchangedCount, 2)

        // Change the data
        util = 75.0
        await scheduler.poll()
        XCTAssertEqual(scheduler.unchangedCount, 0)
    }

    // MARK: - Backoff / interval calculation

    func testNextPollIntervalNormal() {
        let scheduler = PollScheduler()
        // Default pollInterval is 300 (5 min), errorCount=0, unchangedCount=0
        XCTAssertEqual(scheduler.nextPollInterval(), 300)
    }

    func testNextPollIntervalWithErrors() async {
        let scheduler = makeScheduler { throw AuthError.noCredentials }

        await scheduler.poll() // errorCount = 1
        // min(300 * 2^1, 480) = min(600, 480) = 480
        XCTAssertEqual(scheduler.nextPollInterval(), 480)

        await scheduler.poll() // errorCount = 2
        // min(300 * 2^2, 480) = min(1200, 480) = 480
        XCTAssertEqual(scheduler.nextPollInterval(), 480)
    }

    func testNextPollIntervalSlowsForUnchangedData() async {
        let data = makeUsageData()
        let scheduler = makeScheduler { data }

        // Poll 6 times (unchangedCount reaches 5)
        for _ in 0..<6 {
            await scheduler.poll()
        }
        XCTAssertGreaterThanOrEqual(scheduler.unchangedCount, 5)
        // baseInterval * 2 = 600
        XCTAssertEqual(scheduler.nextPollInterval(), 600)
    }

    func testNextPollIntervalSlowsMoreForVeryUnchangedData() async {
        let data = makeUsageData()
        let scheduler = makeScheduler { data }

        // Poll 11 times (unchangedCount reaches 10)
        for _ in 0..<11 {
            await scheduler.poll()
        }
        XCTAssertGreaterThanOrEqual(scheduler.unchangedCount, 10)
        // baseInterval * 5 = 1500
        XCTAssertEqual(scheduler.nextPollInterval(), 1500)
    }

    func testBackoffResetAfterSuccess() async {
        let scheduler = makeScheduler { throw AuthError.noCredentials }

        await scheduler.poll()
        await scheduler.poll()
        XCTAssertEqual(scheduler.errorCount, 2)
        XCTAssertEqual(scheduler.nextPollInterval(), 480) // capped

        // Now succeed
        scheduler.usageFetcher = { self.makeUsageData() }
        await scheduler.poll()
        XCTAssertEqual(scheduler.errorCount, 0)
        XCTAssertEqual(scheduler.nextPollInterval(), 300) // back to normal
    }

    // MARK: - Sleep/wake simulation

    func testSleepWakeCycle() async {
        let data = makeUsageData()
        let scheduler = makeScheduler { data }

        // Normal operation
        await scheduler.poll()
        XCTAssertEqual(scheduler.connectionState, .connected)

        // Sleep
        scheduler.stop()
        XCTAssertNil(scheduler.timer)

        // Simulate wake: set reconnecting state, then start
        scheduler.connectionState = .disconnected("Reconnecting...")
        XCTAssertEqual(scheduler.connectionState, .disconnected("Reconnecting..."))

        scheduler.start()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(scheduler.connectionState, .connected)
        XCTAssertEqual(scheduler.errorCount, 0)
    }

    func testSleepWakeWithExpiredToken() async {
        var shouldFail = true
        let scheduler = makeScheduler {
            if shouldFail {
                throw AuthError.refreshFailed("HTTP 401")
            }
            return self.makeUsageData()
        }

        // Normal operation
        shouldFail = false
        await scheduler.poll()
        XCTAssertEqual(scheduler.connectionState, .connected)

        // Sleep
        scheduler.stop()

        // Wake - token expired, refresh fails
        shouldFail = true
        scheduler.connectionState = .disconnected("Reconnecting...")
        scheduler.start()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Should be in error state
        if case .error(let msg) = scheduler.connectionState {
            XCTAssertTrue(msg.contains("Auth"))
        } else {
            XCTFail("Expected error state after failed refresh, got: \(scheduler.connectionState)")
        }
        XCTAssertEqual(scheduler.errorCount, 1) // reset by start(), then +1 from failure

        // Refresh works now (e.g., network recovered)
        shouldFail = false
        scheduler.pollNow()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(scheduler.connectionState, .connected)
        XCTAssertEqual(scheduler.errorCount, 0)
    }

    func testStartResetsErrorCountFromPreviousSleepCycle() async {
        let scheduler = makeScheduler { throw AuthError.noCredentials }

        // Accumulate errors
        await scheduler.poll()
        await scheduler.poll()
        await scheduler.poll()
        XCTAssertEqual(scheduler.errorCount, 3)

        // Simulate sleep/wake
        scheduler.stop()
        scheduler.usageFetcher = { self.makeUsageData() }
        scheduler.start()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Error count should be 0, not 3
        XCTAssertEqual(scheduler.errorCount, 0)
        XCTAssertEqual(scheduler.connectionState, .connected)
    }

    // MARK: - pollNow after error recovery

    func testPollNowRecoversFromError() async {
        var shouldFail = true
        let scheduler = makeScheduler {
            if shouldFail { throw AuthError.refreshFailed("HTTP 401") }
            return self.makeUsageData()
        }

        await scheduler.poll()
        XCTAssertEqual(scheduler.errorCount, 1)

        // Fix the issue
        shouldFail = false
        scheduler.pollNow()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(scheduler.connectionState, .connected)
        XCTAssertEqual(scheduler.errorCount, 0)
    }

    // MARK: - lastPollTime only set on success

    func testLastPollTimeNotSetOnError() async {
        let scheduler = makeScheduler { throw AuthError.noCredentials }

        await scheduler.poll()

        XCTAssertNil(scheduler.lastPollTime)
    }

    func testLastPollTimeSetOnSuccess() async {
        let scheduler = makeScheduler { self.makeUsageData() }

        let before = Date()
        await scheduler.poll()
        let after = Date()

        XCTAssertNotNil(scheduler.lastPollTime)
        XCTAssertGreaterThanOrEqual(scheduler.lastPollTime!, before)
        XCTAssertLessThanOrEqual(scheduler.lastPollTime!, after)
    }

    // MARK: - Timer scheduling

    func testTimerScheduledAfterPoll() async {
        let scheduler = makeScheduler { self.makeUsageData() }

        await scheduler.poll()

        XCTAssertNotNil(scheduler.timer)
        XCTAssertTrue(scheduler.timer!.isValid)
    }

    func testTimerScheduledAfterError() async {
        let scheduler = makeScheduler { throw AuthError.noCredentials }

        await scheduler.poll()

        XCTAssertNotNil(scheduler.timer)
        XCTAssertTrue(scheduler.timer!.isValid)
    }

    func testStopInvalidatesTimer() async {
        let scheduler = makeScheduler { self.makeUsageData() }

        await scheduler.poll()
        XCTAssertNotNil(scheduler.timer)

        scheduler.stop()
        XCTAssertNil(scheduler.timer)
    }
}
