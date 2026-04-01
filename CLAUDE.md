# CCStatsOSX

macOS menu bar app that displays Claude AI usage stats. Built with Swift/SwiftUI, targeting macOS 13+.

## Build & Run

```bash
swift build                    # Debug build
swift build -c release         # Release build
swift test                     # Run tests
./scripts/build-dmg.sh         # Build DMG for distribution
```

## Project Structure

- `CCStatsOSX/` — All Swift source code
  - `CCStatsOSXApp.swift` — App entry point
  - `Models/` — Data models (AppSettings, KeychainCredentials, UsageData)
  - `Services/` — Auth, Keychain, Usage API, Notifications, Poll scheduling
  - `Views/` — StatusBarController, UsagePopover, SettingsView, ProgressBarView
  - `Utilities/` — ThresholdColor, TimeFormatter
- `Tests/` — XCTest suite (models, utilities, services)
- `scripts/` — Build and release scripts
- `Package.swift` — Swift Package Manager manifest

## Key Architecture

- Reads Claude Code OAuth credentials from macOS Keychain
- Polls `GET https://api.anthropic.com/api/oauth/usage` (zero token cost)
- Displays 5-hour session and 7-day weekly utilization in the menu bar
- Local countdown timers tick between API polls

## Tests

Tests live in `Tests/` and use XCTest with `@testable import CCStatsOSX`. Run with `swift test`.

Covered: Models (decoding, roundtrips, computed properties), Utilities (TimeFormatter), Services (NotificationService threshold logic, error types, enums), AppSettings (enum values, fallback defaults).

Not covered (system/UI boundaries): SwiftUI views, StatusBarController, KeychainService, UsageAPIService, AuthService network calls.

## Code Conventions

- Swift 5.9, SwiftUI for views
- No external dependencies (pure SPM, no third-party packages)
- Settings stored in UserDefaults

## Important Notes

- Never use the OAuth token as an `x-api-key` with the Anthropic SDK — only use `/api/oauth/usage`
- Never spam API endpoints to probe rate limits
- Git operations (add/commit) are handled manually by the developer
