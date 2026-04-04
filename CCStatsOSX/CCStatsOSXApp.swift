import SwiftUI
import Network

@main
struct CCStatsOSXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var scheduler: PollScheduler!
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Request notification permissions
        NSLog("[App] Bundle ID: %@", Bundle.main.bundleIdentifier ?? "nil")
        NotificationService.shared.setup()

        scheduler = PollScheduler()
        statusBarController = StatusBarController(scheduler: scheduler)

        // Load credentials once, then start polling
        NSLog("[App] About to create startup Task")
        Task { @MainActor in
            NSLog("[App] Task started — loading credentials...")
            do {
                try await AuthService.shared.loadCredentials()
                NSLog("[App] Credentials loaded OK")
            } catch {
                NSLog("[App] Credentials failed: %@", "\(error)")
            }
            NSLog("[App] Starting scheduler...")
            self.scheduler.start()
            NSLog("[App] Scheduler started")
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleSleep() {
        Task { @MainActor in scheduler.stop() }
    }

    @objc private func handleWake() {
        Task { @MainActor in
            scheduler.connectionState = .disconnected("Reconnecting...")
            await waitForNetwork()
            try? await AuthService.shared.loadCredentials()
            scheduler.start()
        }
    }

    private func waitForNetwork() async {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "cc.stats.netmonitor")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            final class Box: @unchecked Sendable { var resumed = false }
            let box = Box()
            monitor.pathUpdateHandler = { path in
                guard path.status == .satisfied, !box.resumed else { return }
                box.resumed = true
                monitor.cancel()
                continuation.resume()
            }
            monitor.start(queue: queue)

            // Timeout after 10 seconds — proceed anyway and let poll() handle errors
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                guard !box.resumed else { return }
                box.resumed = true
                monitor.cancel()
                continuation.resume()
            }
        }
    }
}
