import XCTest
@testable import CCStatsOSX

final class AppSettingsTests: XCTestCase {

    // MARK: - MenuBarDisplayMode

    func testMenuBarDisplayModeRawValues() {
        XCTAssertEqual(MenuBarDisplayMode.full.rawValue, "full")
        XCTAssertEqual(MenuBarDisplayMode.minimal.rawValue, "minimal")
        XCTAssertEqual(MenuBarDisplayMode.iconOnly.rawValue, "iconOnly")
    }

    func testMenuBarDisplayModeFromRawValue() {
        XCTAssertEqual(MenuBarDisplayMode(rawValue: "full"), .full)
        XCTAssertEqual(MenuBarDisplayMode(rawValue: "minimal"), .minimal)
        XCTAssertEqual(MenuBarDisplayMode(rawValue: "iconOnly"), .iconOnly)
        XCTAssertNil(MenuBarDisplayMode(rawValue: "invalid"))
    }

    func testMenuBarDisplayModeAllCases() {
        XCTAssertEqual(MenuBarDisplayMode.allCases.count, 3)
        XCTAssertTrue(MenuBarDisplayMode.allCases.contains(.full))
        XCTAssertTrue(MenuBarDisplayMode.allCases.contains(.minimal))
        XCTAssertTrue(MenuBarDisplayMode.allCases.contains(.iconOnly))
    }

    // MARK: - TimeDisplayMode

    func testTimeDisplayModeRawValues() {
        XCTAssertEqual(TimeDisplayMode.countdown.rawValue, "countdown")
        XCTAssertEqual(TimeDisplayMode.absolute.rawValue, "absolute")
    }

    func testTimeDisplayModeFromRawValue() {
        XCTAssertEqual(TimeDisplayMode(rawValue: "countdown"), .countdown)
        XCTAssertEqual(TimeDisplayMode(rawValue: "absolute"), .absolute)
        XCTAssertNil(TimeDisplayMode(rawValue: "invalid"))
    }

    func testTimeDisplayModeAllCases() {
        XCTAssertEqual(TimeDisplayMode.allCases.count, 2)
    }

    // MARK: - AppSettings computed properties

    func testMenuBarDisplayModeComputedProperty() {
        let settings = AppSettings.shared
        let original = settings.menuBarDisplayMode

        settings.menuBarDisplayMode = .minimal
        XCTAssertEqual(settings.menuBarDisplayMode, .minimal)
        XCTAssertEqual(settings.menuBarDisplayModeRaw, "minimal")

        settings.menuBarDisplayMode = .iconOnly
        XCTAssertEqual(settings.menuBarDisplayMode, .iconOnly)
        XCTAssertEqual(settings.menuBarDisplayModeRaw, "iconOnly")

        // Restore
        settings.menuBarDisplayMode = original
    }

    func testTimeDisplayModeComputedProperty() {
        let settings = AppSettings.shared
        let original = settings.timeDisplayMode

        settings.timeDisplayMode = .absolute
        XCTAssertEqual(settings.timeDisplayMode, .absolute)
        XCTAssertEqual(settings.timeDisplayModeRaw, "absolute")

        settings.timeDisplayMode = .countdown
        XCTAssertEqual(settings.timeDisplayMode, .countdown)
        XCTAssertEqual(settings.timeDisplayModeRaw, "countdown")

        // Restore
        settings.timeDisplayMode = original
    }

    func testMenuBarDisplayModeDefaultsToFullForInvalidRaw() {
        let settings = AppSettings.shared
        let original = settings.menuBarDisplayModeRaw

        settings.menuBarDisplayModeRaw = "garbage"
        XCTAssertEqual(settings.menuBarDisplayMode, .full)

        settings.menuBarDisplayModeRaw = original
    }

    func testTimeDisplayModeDefaultsToCountdownForInvalidRaw() {
        let settings = AppSettings.shared
        let original = settings.timeDisplayModeRaw

        settings.timeDisplayModeRaw = "garbage"
        XCTAssertEqual(settings.timeDisplayMode, .countdown)

        settings.timeDisplayModeRaw = original
    }
}
