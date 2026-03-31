import Foundation

class NotificationService {
    static let shared = NotificationService()

    private var notifiedThresholds: Set<String> = []

    func setup() {
        // No setup needed — we use osascript which doesn't require permission
    }

    func checkAndNotify(data: UsageData) {
        if let fiveHour = data.fiveHour, let util = fiveHour.utilization {
            checkThreshold(util, label: "5-hour session", key: "5h")
        }
        if let sevenDay = data.sevenDay, let util = sevenDay.utilization {
            checkThreshold(util, label: "weekly (all models)", key: "7d")
        }
    }

    private func checkThreshold(_ utilization: Double, label: String, key: String) {
        let settings = AppSettings.shared

        if utilization >= Double(settings.criticalThreshold) {
            let notifKey = "\(key)_critical"
            guard !notifiedThresholds.contains(notifKey) else { return }
            notifiedThresholds.insert(notifKey)
            send(
                title: "⚠️ Usage Critical",
                body: "You've used \(Int(utilization))% of your \(label) limit"
            )
        } else if utilization >= Double(settings.warningThreshold) {
            let notifKey = "\(key)_warning"
            guard !notifiedThresholds.contains(notifKey) else { return }
            notifiedThresholds.insert(notifKey)
            send(
                title: "Usage Warning",
                body: "You've used \(Int(utilization))% of your \(label) limit"
            )
        }
    }

    func resetIfNeeded(data: UsageData) {
        if let fiveHour = data.fiveHour, let util = fiveHour.utilization, util < Double(AppSettings.shared.warningThreshold) {
            notifiedThresholds.remove("5h_warning")
            notifiedThresholds.remove("5h_critical")
        }
        if let sevenDay = data.sevenDay, let util = sevenDay.utilization, util < Double(AppSettings.shared.warningThreshold) {
            notifiedThresholds.remove("7d_warning")
            notifiedThresholds.remove("7d_critical")
        }
    }

    private func send(title: String, body: String) {
        NSLog("[Notifications] Sending: %@ - %@", title, body)
        let script = """
        display notification "\(body)" with title "\(title)"
        """
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        process.arguments = ["-e", script]
        try? process.run()
    }
}
