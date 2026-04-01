import Foundation
import Combine

enum ConnectionState {
    case connected
    case disconnected(String)
    case error(String)
}

@MainActor
class PollScheduler: ObservableObject {
    @Published var usageData: UsageData?
    @Published var connectionState: ConnectionState = .disconnected("Starting...")
    @Published var lastUpdated: Date?

    private var timer: Timer?
    private var unchangedCount = 0
    private var errorCount = 0
    private var lastDataHash: Int?
    private var lastPollTime: Date?
    private var isPolling = false
    private let settings = AppSettings.shared

    func start() {
        stop()
        Task { await poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pollNow() {
        // Throttle: don't poll if we polled within the last 60 seconds
        if let lastPoll = lastPollTime, Date().timeIntervalSince(lastPoll) < 60 {
            return
        }
        Task { await poll() }
    }

    private func poll() async {
        // Prevent concurrent polls
        guard !isPolling else { return }
        isPolling = true
        defer { isPolling = false }

        do {
            #if DEBUG
            let data = MockUsageService.fetchUsage()
            #else
            let data = try await UsageAPIService.fetchUsage()
            #endif
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

            // Check for threshold notifications
            NotificationService.shared.checkAndNotify(data: data)
            NotificationService.shared.resetIfNeeded(data: data)
            lastPollTime = Date()
        } catch is KeychainError {
            connectionState = .disconnected("Claude Code not found")
            errorCount += 1
        } catch let error as AuthError {
            connectionState = .error("Auth: \(error)")
            errorCount += 1
            // Force re-read from Keychain on next attempt — credentials
            // may have changed or Keychain may need re-authorization
            try? await AuthService.shared.reloadCredentials()
        } catch let error as UsageAPIError {
            switch error {
            case .httpError(429, _):
                connectionState = .error("Rate limited — retrying soon")
            default:
                connectionState = .error(error.localizedDescription ?? "API error")
            }
            errorCount += 1
        } catch {
            connectionState = .error(error.localizedDescription)
            errorCount += 1
        }

        scheduleNext()
    }

    private func scheduleNext() {
        timer?.invalidate()

        let baseInterval = TimeInterval(settings.pollInterval)
        let interval: TimeInterval

        if errorCount > 0 {
            // Exponential backoff: 2m, 4m, 8m (capped at 8m)
            interval = min(baseInterval * pow(2, Double(errorCount)), 480)
        } else if unchangedCount >= 10 {
            interval = baseInterval * 5
        } else if unchangedCount >= 5 {
            interval = baseInterval * 2
        } else {
            interval = baseInterval
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.poll()
            }
        }
    }
}
