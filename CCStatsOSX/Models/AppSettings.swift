import Foundation
import SwiftUI

enum MenuBarDisplayMode: String, CaseIterable {
    case full
    case minimal
    case iconOnly
}

enum TimeDisplayMode: String, CaseIterable {
    case countdown   // "2h 14m"
    case absolute    // "Today 4:00 PM"
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("pollInterval") var pollInterval: Int = 900 // 15 minutes default
    @AppStorage("showFiveHourPercent") var showFiveHourPercent: Bool = true
    @AppStorage("showSevenDayPercent") var showSevenDayPercent: Bool = true
    @AppStorage("showCountdown") var showCountdown: Bool = true
    @AppStorage("showSonnet") var showSonnet: Bool = true
    @AppStorage("showOpus") var showOpus: Bool = true
    @AppStorage("showCowork") var showCowork: Bool = false
    @AppStorage("warningThreshold") var warningThreshold: Int = 70
    @AppStorage("criticalThreshold") var criticalThreshold: Int = 90
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("menuBarDisplayMode") var menuBarDisplayModeRaw: String = MenuBarDisplayMode.full.rawValue
    @AppStorage("timeDisplayMode") var timeDisplayModeRaw: String = TimeDisplayMode.countdown.rawValue

    var menuBarDisplayMode: MenuBarDisplayMode {
        get { MenuBarDisplayMode(rawValue: menuBarDisplayModeRaw) ?? .full }
        set { menuBarDisplayModeRaw = newValue.rawValue }
    }

    var timeDisplayMode: TimeDisplayMode {
        get { TimeDisplayMode(rawValue: timeDisplayModeRaw) ?? .countdown }
        set { timeDisplayModeRaw = newValue.rawValue }
    }
}
