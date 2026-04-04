import Foundation
import Combine

enum ConnectionState: Equatable {
    case connected
    case disconnected(String)
    case error(String)
}

@MainActor
class PollScheduler: ObservableObject {
    @Published var usageData: UsageData?
    @Published var connectionState: ConnectionState = .disconnected("Starting...")
    @Published var lastUpdated: Date?

    private(set) var timer: Timer?
    private(set) var unchangedCount = 0
    private(set) var errorCount = 0
    private var lastDataHash: Int?
    private(set) var lastPollTime: Date?
    @Published private(set) var isPolling = false
    private let settings = AppSettings.shared

    /// Injectable usage fetcher for testing. Defaults to the real API service.
    var usageFetcher: (() async throws -> UsageData)?

    func start() {
        stop()
        errorCount = 0
        unchangedCount = 0
        Task { await poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pollNow() {
        NSLog("[Poll] pollNow called — isPolling=%d, errorCount=%d", isPolling ? 1 : 0, errorCount)
        guard !isPolling else {
            NSLog("[Poll] pollNow BLOCKED — poll already in progress")
            return
        }
        // Reset backoff so a manual refresh gets normal scheduling after
        errorCount = 0
        unchangedCount = 0
        timer?.invalidate()
        Task { await poll() }
    }

    func poll() async {
        // Prevent concurrent polls
        guard !isPolling else {
            NSLog("[Poll] poll() BLOCKED — already polling")
            return
        }
        isPolling = true
        defer { isPolling = false }

        NSLog("[Poll] Starting poll...")

        do {
            let data: UsageData
            if let fetcher = usageFetcher {
                data = try await fetcher()
            } else {
                #if DEBUG
                data = MockUsageService.fetchUsage()
                #else
                data = try await UsageAPIService.fetchUsage()
                #endif
            }
            let newHash = "\(data.fiveHour?.utilization ?? -1)_\(data.sevenDay?.utilization ?? -1)".hashValue

            if newHash == lastDataHash {
                unchangedCount += 1
            } else {
                unchangedCount = 0
                lastDataHash = newHash
            }

            errorCount = 0
            usageData = data
            connectionState = .connected
            lastUpdated = Date()

            NSLog("[Poll] Success — 5h=%.1f%% 7d=%.1f%%", data.fiveHour?.utilization ?? 0, data.sevenDay?.utilization ?? 0)

            // Check for threshold notifications
            NotificationService.shared.checkAndNotify(data: data)
            NotificationService.shared.resetIfNeeded(data: data)
            lastPollTime = Date()
        } catch is KeychainError {
            connectionState = .disconnected("Claude Code not found")
            errorCount += 1
            NSLog("[Poll] KeychainError — errorCount=%d", errorCount)
        } catch let error as AuthError {
            connectionState = .error("Auth: \(error)")
            errorCount += 1
            NSLog("[Poll] AuthError: %@ — errorCount=%d", "\(error)", errorCount)
        } catch let error as UsageAPIError {
            switch error {
            case .httpError(429, _):
                connectionState = .error("Rate limited — retrying soon")
            default:
                connectionState = .error(error.localizedDescription ?? "API error")
            }
            errorCount += 1
            NSLog("[Poll] UsageAPIError: %@ — errorCount=%d", "\(error)", errorCount)
        } catch {
            connectionState = .error(error.localizedDescription)
            errorCount += 1
            NSLog("[Poll] Unknown error: %@ — errorCount=%d", error.localizedDescription, errorCount)
        }

        scheduleNext()
    }

    /// Calculate the next poll interval based on current state.
    /// Exposed for testing.
    func nextPollInterval() -> TimeInterval {
        let baseInterval = TimeInterval(settings.pollInterval)

        if errorCount > 0 {
            // Start retry at 30s, doubling each time, capped at 480s
            return min(30 * pow(2, Double(errorCount - 1)), 480)
        } else if unchangedCount >= 10 {
            return baseInterval * 5
        } else if unchangedCount >= 5 {
            return baseInterval * 2
        } else {
            return baseInterval
        }
    }

    private func scheduleNext() {
        timer?.invalidate()
        let interval = nextPollInterval()
        NSLog("[Poll] Next poll in %.0fs (errorCount=%d, unchangedCount=%d)", interval, errorCount, unchangedCount)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.poll()
            }
        }
    }
}
