import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            Form {
                Section("Menu Bar Display") {
                    Picker("Mode", selection: Binding(
                        get: { settings.menuBarDisplayMode },
                        set: { settings.menuBarDisplayMode = $0 }
                    )) {
                        Text("Full").tag(MenuBarDisplayMode.full)
                        Text("Minimal").tag(MenuBarDisplayMode.minimal)
                        Text("Icon Only").tag(MenuBarDisplayMode.iconOnly)
                    }
                    Toggle("Show reset time", isOn: $settings.showCountdown)
                    Toggle("Show 7-day percentage", isOn: $settings.showSevenDayPercent)
                    Picker("Time format", selection: Binding(
                        get: { settings.timeDisplayMode },
                        set: { settings.timeDisplayMode = $0 }
                    )) {
                        Text("Countdown (2h 14m)").tag(TimeDisplayMode.countdown)
                        Text("Date (Today 4:00 PM)").tag(TimeDisplayMode.absolute)
                    }
                }

                Section("Visible Categories") {
                    Toggle("Sonnet weekly", isOn: $settings.showSonnet)
                    Toggle("Opus weekly", isOn: $settings.showOpus)
                    Toggle("Cowork weekly", isOn: $settings.showCowork)
                }

                Section {
                    Picker("Refresh interval", selection: $settings.pollInterval) {
                        Text("5 minutes").tag(300)
                        Text("10 minutes").tag(600)
                        Text("15 minutes").tag(900)
                        Text("30 minutes").tag(1800)
                    }
                    Text("The usage API has a strict rate limit (~5 requests per token). A longer interval helps avoid HTTP 429 errors.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Polling")
                }

                Section {
                    Text("Get notified when your usage reaches these levels. Warnings appear as macOS notifications.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("Warning at")
                        Spacer()
                        TextField("", value: $settings.warningThreshold, format: .number)
                            .frame(width: 40)
                            .textFieldStyle(.roundedBorder)
                        Text("%")
                    }
                    HStack {
                        Text("Critical at")
                        Spacer()
                        TextField("", value: $settings.criticalThreshold, format: .number)
                            .frame(width: 40)
                            .textFieldStyle(.roundedBorder)
                        Text("%")
                    }
                } header: {
                    Text("Thresholds")
                }

                Section("General") {
                    Toggle("Launch at login", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { newValue in
                            settings.launchAtLogin = newValue
                            if newValue {
                                try? SMAppService.mainApp.register()
                            } else {
                                try? SMAppService.mainApp.unregister()
                            }
                        }
                    ))
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 320, height: 550)
        .background(.ultraThinMaterial)
    }
}
