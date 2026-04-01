import SwiftUI

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
        Task {
            try? await AuthService.shared.loadCredentials()
            await scheduler.start()
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
        Task { @MainActor in scheduler.start() }
    }
}
