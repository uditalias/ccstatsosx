import SwiftUI
import Combine

@MainActor
class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel?
    private var eventMonitor: Any?
    private var countdownTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let scheduler: PollScheduler
    private let settings = AppSettings.shared
    private var panelTopY: CGFloat = 0  // remember the top edge for pinned animation

    // Claude brand color - warm terracotta/coral from the logo
    private let claudeColor = NSColor(red: 0.85, green: 0.55, blue: 0.40, alpha: 1.0)
    private let claudeColorLight = NSColor(red: 0.85, green: 0.55, blue: 0.40, alpha: 0.3)

    init(scheduler: PollScheduler) {
        self.scheduler = scheduler
        setupStatusItem()
        startCountdownTimer()
        observeChanges()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.imagePosition = .imageLeading
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
        updateMenuBar()
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        menu.addItem(withTitle: "Refresh Now", action: #selector(menuRefresh), keyEquivalent: "r").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Claude Usage Settings", action: #selector(menuOpenWebSettings), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit CCStatsOSX", action: #selector(menuQuit), keyEquivalent: "q").target = self

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        // Reset menu so left-click still opens the popover
        statusItem.menu = nil
    }

    @objc private func menuRefresh() {
        scheduler.pollNow()
    }

    @objc private func menuOpenWebSettings() {
        if let url = URL(string: "https://claude.ai/settings/usage") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func menuQuit() {
        NSApplication.shared.terminate(nil)
    }

    private func getOrCreatePanel() -> NSPanel {
        if let panel { return panel }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 10),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        p.isFloatingPanel = true
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovable = false

        // Use native NSVisualEffectView for proper vibrancy (like Battery panel)
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .menu
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.layer?.masksToBounds = true

        let hostingView = NSHostingView(
            rootView: UsagePopover(scheduler: scheduler, onHeightChange: { [weak self] newHeight in
                self?.animatePanelHeight(to: newHeight)
            })
        )
        // Prevent NSHostingView from imposing its own min/max size constraints
        // so it does not fight the animated frame we set from AppKit.
        hostingView.sizingOptions = [.intrinsicContentSize]
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Remove the default opaque background from the hosting view
        DispatchQueue.main.async {
            hostingView.layer?.backgroundColor = .clear
            // Walk the view hierarchy to find and clear any opaque backgrounds
            func clearBackground(_ view: NSView) {
                view.layer?.backgroundColor = .clear
                if let effectView = view as? NSVisualEffectView, effectView !== visualEffect {
                    effectView.isHidden = true
                }
                for subview in view.subviews {
                    clearBackground(subview)
                }
            }
            clearBackground(hostingView)
        }

        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        p.contentView = visualEffect

        panel = p
        return p
    }

    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        panel = nil  // Reset so next open starts fresh on main view
        stopEventMonitor()
    }

    /// Animate the panel's height while keeping the top edge pinned.
    private func animatePanelHeight(to newHeight: CGFloat) {
        guard let p = panel, p.isVisible else { return }
        let panelWidth = p.frame.width
        // Pin the top edge: top = origin.y + height, so new origin.y = top - newHeight
        let newOriginY = panelTopY - newHeight
        let newFrame = NSRect(x: p.frame.origin.x, y: newOriginY, width: panelWidth, height: newHeight)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            p.animator().setFrame(newFrame, display: true, animate: true)
        }
    }


    private func observeChanges() {
        scheduler.$usageData
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBar() }
            .store(in: &cancellables)

        scheduler.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBar() }
            .store(in: &cancellables)
    }

    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBar()
            }
        }
    }

    // MARK: - Mini bar drawing

    private func drawMiniBar(utilization: Double) -> NSImage {
        let barWidth: CGFloat = 5
        let barHeight: CGFloat = 14
        let totalWidth: CGFloat = barWidth + 2
        let totalHeight: CGFloat = 18

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))
        image.lockFocus()

        let x: CGFloat = 1
        let y = (totalHeight - barHeight) / 2

        // Background
        let bgRect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 2, yRadius: 2)
        claudeColorLight.setFill()
        bgPath.fill()

        // Fill from bottom
        let fill = CGFloat(min(utilization, 100) / 100)
        if fill > 0 {
            let fillHeight = barHeight * fill
            let fillRect = NSRect(x: x, y: y, width: barWidth, height: fillHeight)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2)
            barColor(for: utilization).setFill()
            fillPath.fill()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    // MARK: - Inline bar for attributed string

    private func inlineBarAttachment(utilization: Double) -> NSAttributedString {
        let barWidth: CGFloat = 5
        let barHeight: CGFloat = 14
        let totalHeight: CGFloat = 18

        let image = NSImage(size: NSSize(width: barWidth + 2, height: totalHeight))
        image.lockFocus()

        let x: CGFloat = 1
        let y = (totalHeight - barHeight) / 2

        let bgRect = NSRect(x: x, y: y, width: barWidth, height: barHeight)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 2, yRadius: 2)
        claudeColorLight.setFill()
        bgPath.fill()

        let fill = CGFloat(min(utilization, 100) / 100)
        if fill > 0 {
            let fillHeight = barHeight * fill
            let fillRect = NSRect(x: x, y: y, width: barWidth, height: fillHeight)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2, yRadius: 2)
            barColor(for: utilization).setFill()
            fillPath.fill()
        }

        image.unlockFocus()
        image.isTemplate = false

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: -4, width: barWidth + 2, height: totalHeight)
        return NSAttributedString(attachment: attachment)
    }

    // MARK: - Update

    func updateMenuBar() {
        guard let button = statusItem.button else { return }

        switch scheduler.connectionState {
        case .disconnected(let reason):
            button.image = nil
            button.attributedTitle = NSAttributedString(string: reason, attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.controlTextColor
            ])
            return

        case .error:
            button.image = nil
            button.attributedTitle = NSAttributedString(string: "⚠", attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.systemYellow
            ])
            return

        case .connected:
            break
        }

        guard let data = scheduler.usageData else { return }

        let fiveHourUtil = data.fiveHour?.utilization ?? 0
        let sevenDayUtil = data.sevenDay?.utilization ?? 0

        button.image = nil

        let attributed = NSMutableAttributedString()

        let mainFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        let labelFont = NSFont.systemFont(ofSize: 9, weight: .semibold)
        let textColor = NSColor.controlTextColor
        let fiveHourColor = percentColor(for: fiveHourUtil)
        let sevenDayColor = percentColor(for: sevenDayUtil)

        switch settings.menuBarDisplayMode {
        case .full:
            // 5h bar + label + percentage
            if settings.showFiveHourPercent {
                attributed.append(inlineBarAttachment(utilization: fiveHourUtil))
                attributed.append(NSAttributedString(string: " 5H ", attributes: [
                    .font: labelFont,
                    .foregroundColor: textColor
                ]))
                attributed.append(NSAttributedString(string: "\(Int(fiveHourUtil))%", attributes: [
                    .font: mainFont,
                    .foregroundColor: fiveHourColor
                ]))
            }
            // 5h time
            if settings.showCountdown, let fiveHour = data.fiveHour, let resetDate = fiveHour.resetsAtDate {
                let timeText = formatTime(resetDate)
                attributed.append(NSAttributedString(string: " \(timeText)", attributes: [
                    .font: mainFont,
                    .foregroundColor: textColor
                ]))
            }
            // Separator + 7d bar + label + percentage + time
            if settings.showSevenDayPercent {
                attributed.append(NSAttributedString(string: " │ ", attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: textColor
                ]))
                attributed.append(inlineBarAttachment(utilization: sevenDayUtil))
                attributed.append(NSAttributedString(string: " 7D ", attributes: [
                    .font: labelFont,
                    .foregroundColor: textColor
                ]))
                attributed.append(NSAttributedString(string: "\(Int(sevenDayUtil))%", attributes: [
                    .font: mainFont,
                    .foregroundColor: sevenDayColor
                ]))
                if settings.showCountdown, let sevenDay = data.sevenDay, let resetDate = sevenDay.resetsAtDate {
                    let timeText = formatTime(resetDate)
                    attributed.append(NSAttributedString(string: " \(timeText)", attributes: [
                        .font: mainFont,
                        .foregroundColor: textColor
                    ]))
                }
            }

        case .minimal:
            if settings.showFiveHourPercent {
                attributed.append(inlineBarAttachment(utilization: fiveHourUtil))
                attributed.append(NSAttributedString(string: " 5H ", attributes: [
                    .font: labelFont,
                    .foregroundColor: textColor
                ]))
                attributed.append(NSAttributedString(string: "\(Int(fiveHourUtil))%", attributes: [
                    .font: mainFont,
                    .foregroundColor: fiveHourColor
                ]))
            }
            if settings.showCountdown, let fiveHour = data.fiveHour, let resetDate = fiveHour.resetsAtDate {
                let timeText = formatTime(resetDate)
                attributed.append(NSAttributedString(string: " \(timeText)", attributes: [
                    .font: mainFont,
                    .foregroundColor: textColor
                ]))
            }

        case .iconOnly:
            attributed.append(inlineBarAttachment(utilization: fiveHourUtil))
            attributed.append(NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: 2)]))
            attributed.append(inlineBarAttachment(utilization: sevenDayUtil))
        }

        button.attributedTitle = attributed
    }

    private func formatTime(_ date: Date) -> String {
        switch settings.timeDisplayMode {
        case .countdown:
            return "⏱" + TimeFormatter.countdown(to: date)
        case .absolute:
            return TimeFormatter.resetDate(date)
        }
    }

    /// Color for percentage text in menu bar — only colored at warning/critical
    private func percentColor(for utilization: Double) -> NSColor {
        if utilization >= Double(settings.criticalThreshold) {
            return .systemRed
        } else if utilization >= Double(settings.warningThreshold) {
            return .systemOrange
        } else {
            return .controlTextColor
        }
    }

    private func barColor(for utilization: Double) -> NSColor {
        if utilization >= Double(settings.criticalThreshold) {
            return .systemRed
        } else if utilization >= Double(settings.warningThreshold) {
            return .systemOrange
        } else {
            return claudeColor
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        let p = getOrCreatePanel()

        if p.isVisible {
            closePanel()
        } else {
            guard let button = statusItem.button,
                  let window = button.window else { return }

            let buttonFrame = window.convertToScreen(button.convert(button.bounds, to: nil))
            let panelWidth: CGFloat = 340

            // Position below the status item, centered
            let x = buttonFrame.midX - panelWidth / 2
            let y = buttonFrame.minY - 4

            p.setFrameTopLeftPoint(NSPoint(x: x, y: y))

            // Size to fit content
            if let contentView = p.contentView {
                let fitting = contentView.fittingSize
                p.setContentSize(NSSize(width: panelWidth, height: fitting.height))
                p.setFrameTopLeftPoint(NSPoint(x: x, y: y))
            }

            // Remember the top edge (origin.y + height) so we can pin it during animation
            panelTopY = p.frame.origin.y + p.frame.height

            p.orderFrontRegardless()
            startEventMonitor()
        }
    }
}
