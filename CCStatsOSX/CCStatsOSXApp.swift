import SwiftUI
import Carbon

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
    private var hotKeyRef: EventHotKeyRef?

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

        // Register global hotkey: ⌘⇧U
        registerGlobalHotKey()

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

    // MARK: - Global Hotkey (⌘⇧U)

    private func registerGlobalHotKey() {
        let hotKeyID = EventHotKeyID(signature: FourCharCode(0x43435355), // "CCSU"
                                      id: 1)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            DispatchQueue.main.async {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.statusBarController.toggleFromHotKey()
                }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)

        // ⌘⇧U: keycode 32 = 'U', cmdKey + shiftKey
        RegisterEventHotKey(UInt32(kVK_ANSI_U),
                           UInt32(cmdKey | shiftKey),
                           hotKeyID,
                           GetApplicationEventTarget(),
                           0,
                           &hotKeyRef)
    }
}
