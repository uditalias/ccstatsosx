import SwiftUI
import ServiceManagement

// PreferenceKey to bubble up measured content height
private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct UsagePopover: View {
    @ObservedObject var scheduler: PollScheduler
    @ObservedObject private var settings = AppSettings.shared
    @State private var showSettings = false
    @State private var contentHeight: CGFloat = 0

    /// Called when the measured content height changes; used by AppKit to animate the panel frame.
    var onHeightChange: ((CGFloat) -> Void)?

    private let claudeColor = Color(red: 0.78, green: 0.38, blue: 0.22)

    private var hasCategoryData: Bool {
        let data = scheduler.usageData
        return data?.sevenDaySonnet != nil || data?.sevenDayOpus != nil || data?.sevenDayCowork != nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            if showSettings {
                settingsView
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                        }
                    )
            } else {
                usageView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading),
                        removal: .move(edge: .leading)
                    ))
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                        }
                    )
            }
        }
        .onPreferenceChange(ContentHeightKey.self) { newHeight in
            guard newHeight > 0 else { return }
            contentHeight = newHeight
            onHeightChange?(newHeight)
        }
        .frame(width: 340, height: contentHeight > 0 ? contentHeight : nil)
        .clipped()
        .animation(.easeInOut(duration: 0.25), value: showSettings)
    }

    // MARK: - Usage View

    private var usageView: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center) {
                Text("Claude Usage")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                if let lastUpdated = scheduler.lastUpdated {
                    Text(TimeFormatter.timeSince(lastUpdated))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary.opacity(0.35))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                }

                Button(action: { scheduler.pollNow() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary.opacity(0.4))
                        .rotationEffect(.degrees(0))
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help("Refresh")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if let data = scheduler.usageData {
                VStack(spacing: 0) {
                    if let fiveHour = data.fiveHour, let util = fiveHour.utilization {
                        ProgressBarView(value: util, label: "Session", icon: "bolt.fill", resetDate: fiveHour.resetsAtDate)
                    }

                    sectionDivider

                    if let sevenDay = data.sevenDay, let util = sevenDay.utilization {
                        ProgressBarView(value: util, label: "Weekly · All", icon: "calendar", resetDate: sevenDay.resetsAtDate)
                    }

                    if settings.showSonnet, let sonnet = data.sevenDaySonnet, let util = sonnet.utilization {
                        sectionDivider
                        ProgressBarView(value: util, label: "Weekly · Sonnet", icon: "sparkle", resetDate: sonnet.resetsAtDate)
                    }

                    if settings.showOpus, let opus = data.sevenDayOpus, let util = opus.utilization {
                        sectionDivider
                        ProgressBarView(value: util, label: "Weekly · Opus", icon: "star.fill", resetDate: opus.resetsAtDate)
                    }

                    if settings.showCowork, let cowork = data.sevenDayCowork, let util = cowork.utilization {
                        sectionDivider
                        ProgressBarView(value: util, label: "Weekly · Cowork", icon: "person.2.fill", resetDate: cowork.resetsAtDate)
                    }

                    if let extra = data.extraUsage, extra.isEnabled == true, let util = extra.utilization {
                        sectionDivider
                        ProgressBarView(value: util, label: "Extra Usage", icon: "plus.circle.fill", resetDate: nil)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            } else {
                // Loading / error states
                VStack(spacing: 12) {
                    switch scheduler.connectionState {
                    case .disconnected(let reason):
                        Image(systemName: "bolt.slash.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.primary.opacity(0.15))
                        Text(reason)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary.opacity(0.4))
                    case .error(let msg):
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(.orange.opacity(0.7))
                        Text(msg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    case .connected:
                        ProgressView()
                            .controlSize(.small)
                            .tint(claudeColor)
                        Text("Loading...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary.opacity(0.35))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding(.vertical, 20)
            }

            // Web link
            Divider().opacity(0.3)

            Button(action: {
                if let url = URL(string: "https://claude.ai/settings/usage") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "safari")
                        .font(.system(size: 11, weight: .medium))
                    Text("Open Usage in Browser")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.primary.opacity(0.5))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderless)
            .focusable(false)

            // Footer
            Divider().opacity(0.3)

            HStack(spacing: 12) {
                Button(action: { showSettings = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "gear")
                            .font(.system(size: 10, weight: .medium))
                        Text("Settings")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.primary.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(Capsule())
                }
                .buttonStyle(.borderless)
                .focusable(false)

                Spacer()

                SubscriptionLabel()

                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary.opacity(0.3))
                        .padding(4)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Circle())
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .help("Quit")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
    }

    private var sectionDivider: some View {
        Divider()
            .opacity(0.4)
            .padding(.vertical, 2)
    }

    // MARK: - Settings View (inline)

    private var settingsView: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: { showSettings = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Settings")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.borderless)
                .focusable(false)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                sectionHeader("Display")
                settingsPickerRow("Mode", selection: Binding(
                    get: { settings.menuBarDisplayMode },
                    set: { settings.menuBarDisplayMode = $0 }
                )) {
                    Text("Full").tag(MenuBarDisplayMode.full)
                    Text("Minimal").tag(MenuBarDisplayMode.minimal)
                    Text("Icon Only").tag(MenuBarDisplayMode.iconOnly)
                }
                settingsToggleRow("Show reset time", isOn: $settings.showCountdown)
                settingsToggleRow("Show 7-day usage", isOn: $settings.showSevenDayPercent)
                settingsPickerRow("Time format", selection: Binding(
                    get: { settings.timeDisplayMode },
                    set: { settings.timeDisplayMode = $0 }
                )) {
                    Text("Countdown").tag(TimeDisplayMode.countdown)
                    Text("Date & Time").tag(TimeDisplayMode.absolute)
                }

                Divider().padding(.vertical, 4)

                if hasCategoryData {
                    sectionHeader("Categories")
                    if scheduler.usageData?.sevenDaySonnet != nil {
                        settingsToggleRow("Sonnet weekly", isOn: $settings.showSonnet)
                    }
                    if scheduler.usageData?.sevenDayOpus != nil {
                        settingsToggleRow("Opus weekly", isOn: $settings.showOpus)
                    }
                    if scheduler.usageData?.sevenDayCowork != nil {
                        settingsToggleRow("Cowork weekly", isOn: $settings.showCowork)
                    }
                    Divider().padding(.vertical, 4)
                }

                sectionHeader("Refresh")
                settingsPickerRow("Interval", selection: $settings.pollInterval) {
                    Text("5 minutes").tag(300)
                    Text("10 minutes").tag(600)
                    Text("15 minutes").tag(900)
                    Text("30 minutes").tag(1800)
                }

                Divider().padding(.vertical, 4)

                sectionHeader("General")
                settingsToggleRow("Launch at login", isOn: Binding(
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
            .padding(.bottom, 12)
        }
    }

    // MARK: - Settings Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.primary.opacity(0.4))
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private func settingsToggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
    }

    private func settingsPickerRow<SelectionValue: Hashable, Content: View>(
        _ label: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Picker("", selection: selection) {
                content()
            }
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
    }
}

struct SubscriptionLabel: View {
    @State private var subscriptionType: String = ""

    var body: some View {
        if !subscriptionType.isEmpty {
            Text(subscriptionType)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(red: 0.78, green: 0.38, blue: 0.22))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color(red: 0.78, green: 0.38, blue: 0.22).opacity(0.12))
                )
                .padding(.trailing, 8)
        }
        EmptyView()
            .task {
                if let cached = await AuthService.shared.getCachedCredentials() {
                    subscriptionType = cached.claudeAiOauth.subscriptionType?.capitalized ?? ""
                }
            }
    }
}

