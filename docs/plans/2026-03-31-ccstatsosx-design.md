# CCStatsOSX — Design Document

A macOS menu bar app that displays Claude usage statistics at a glance.

## Problem

When working with Claude across multiple channels (Claude Code CLI, Desktop app, Web), there's no single place to see current usage status without navigating to the web settings page. Users need a persistent, always-visible indicator of their rate limit utilization and reset timers.

## Solution

A native macOS menu bar app (NSStatusItem) that polls the Claude usage API and displays live usage data directly in the menu bar — no interaction required.

---

## Architecture

### Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI
- **Target:** macOS 13+ (Ventura)
- **Distribution:** Signed `.dmg`

### Data Source

**Primary endpoint:** `GET https://api.anthropic.com/api/oauth/usage`

This is the same endpoint Claude Code's `/usage` command uses internally (source: `src/services/api/usage.ts`). It returns utilization data with zero token cost.

**Request headers:**
```
Authorization: Bearer <accessToken>
anthropic-beta: oauth-2025-04-20
Content-Type: application/json
```

**Response shape:**
```json
{
  "five_hour": { "utilization": 32.0, "resets_at": "2026-03-31T16:00:01+00:00" },
  "seven_day": { "utilization": 10.0, "resets_at": "2026-04-06T11:00:01+00:00" },
  "seven_day_sonnet": { "utilization": 3.0, "resets_at": "2026-04-01T19:00:00+00:00" },
  "seven_day_opus": null,
  "seven_day_oauth_apps": null,
  "seven_day_cowork": null,
  "iguana_necktie": null,
  "extra_usage": {
    "is_enabled": false,
    "monthly_limit": null,
    "used_credits": null,
    "utilization": null
  }
}
```

### Authentication

Credentials are read from the macOS Keychain — the same store Claude Code uses.

**Keychain entry:**
- Service: `Claude Code-credentials`
- Account: system username (`NSUserName()`)
- Data: JSON containing `claudeAiOauth.accessToken`, `claudeAiOauth.refreshToken`, `claudeAiOauth.expiresAt`, `organizationUuid`, `claudeAiOauth.subscriptionType`

**Token refresh (when expired):**
- Check `expiresAt` with 5-minute buffer before each API call (same as Claude Code)
- If expired: `POST https://platform.claude.com/v1/oauth/token`
  ```json
  {
    "grant_type": "refresh_token",
    "refresh_token": "<refreshToken>",
    "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
    "scope": "user:profile user:inference user:sessions:claude_code user:mcp_servers user:file_upload"
  }
  ```
- Save refreshed tokens back to Keychain (same format)
- This is identical to Claude Code's own refresh flow (`src/services/oauth/client.ts`)

### Polling Strategy

```
On app launch:
  → Call API immediately
  → Start poll timer at 60s (configurable)

Every poll interval:
  → Check token expiry → refresh if needed
  → Call GET /api/oauth/usage
  → Update UI with new data

Smart backoff when idle:
  → 5 consecutive unchanged responses → slow to 2x interval
  → 10 consecutive unchanged → slow to 5x interval
  → Any data change → reset to base interval

Countdown timers:
  → Tick locally every second from resetsAt timestamps
  → Always accurate between API polls

Error handling:
  → API error → exponential backoff (2m → 4m → 8m)
  → Success → reset to base interval
  → Token refresh failure → show "⚠ Not connected" in menu bar
```

---

## UI Design

### Menu Bar Status Item (always visible)

The primary display — a live dashboard in the menu bar, no click needed.

**Default mode:**
```
☰ 32% ⏱ 2h14m │ 7d: 10%
```

Components (all configurable show/hide):
- Icon: small Claude/gauge icon
- 5-hour utilization percentage
- Countdown timer to 5-hour reset
- Separator
- 7-day utilization percentage

**Minimal mode:**
```
☰ 32% ⏱ 2h14m
```

**Icon-only mode:**
```
☰ ██░░
```
A tiny inline progress bar (battery-style).

**Color coding** (applied to text and progress bars):
- 0–69%: System blue (default accent)
- 70–89%: Yellow/amber
- 90–100%: Red

**Live updates:**
- Percentages refresh on each API poll
- Countdown timer ticks every second
- Colors shift dynamically as usage changes

### Popover (click to expand)

A detailed view with full breakdowns, opened by clicking the menu bar item.

```
┌─────────────────────────────────────────────┐
│  Claude Usage                    ⟳ 30s ago  │
│─────────────────────────────────────────────│
│                                             │
│  Current Session (5h)                       │
│  ████████░░░░░░░░░░░░░░░░  32%             │
│  Resets in 2h 14m                           │
│                                             │
│  Weekly (All models)                        │
│  ██░░░░░░░░░░░░░░░░░░░░░░  10%             │
│  Resets Mon 2:00 PM                         │
│                                             │
│  Weekly (Sonnet only)                       │
│  █░░░░░░░░░░░░░░░░░░░░░░░   3%             │
│  Resets Wed 10:00 PM                        │
│                                             │
│─────────────────────────────────────────────│
│  ⚙ Settings                    Max plan     │
└─────────────────────────────────────────────┘
```

**Design:**
- Native SwiftUI popover
- `.ultraThinMaterial` background for macOS glass/vibrancy effect
- Progress bars with color-coded fills
- Live countdown timers
- "Last updated" indicator
- Plan type in footer (from `subscriptionType`)
- Conditional sections: Opus, Cowork, Extra Usage only shown when data is non-null

### Settings Panel

Accessible via gear icon in the popover.

**Sections:**
- **Display:** Which elements show in menu bar (5h%, 7d%, countdown, mini bar)
- **Visibility:** Show/hide individual model tiers (Sonnet, Opus, Cowork)
- **Polling:** Base interval (30s / 60s / 2m / 5m)
- **Thresholds:** Color change percentages (defaults: 70% yellow, 90% red)
- **General:** Launch at login toggle
- **Extra Usage:** Show extra usage section if enabled on account

---

## App Lifecycle

### First Run
1. Check if `Claude Code-credentials` exists in Keychain
2. If yes → start polling, show data
3. If no → show "Claude Code not found" in menu bar with install prompt

### Launch at Login
- `SMAppService.mainApp` registration (modern macOS API)
- Toggle in settings

### Sleep/Wake
- Pause polling on sleep
- Resume + immediate poll on wake

### Error States
- No Keychain entry → "Claude Code not found"
- Token refresh failure → "⚠ Not connected"
- API errors → "⚠ Error" with retry backoff
- No network → show last known data + "offline" indicator

---

## Project Structure

```
CCStatsOSX/
├── CCStatsOSXApp.swift              # App entry point, NSStatusItem setup
├── Models/
│   ├── UsageData.swift              # Codable models for API response
│   └── AppSettings.swift            # UserDefaults-backed preferences
├── Services/
│   ├── KeychainService.swift        # Read/write Claude Code credentials
│   ├── AuthService.swift            # Token expiry check, refresh flow
│   ├── UsageAPIService.swift        # GET /api/oauth/usage polling
│   └── PollScheduler.swift          # Timer + smart backoff logic
├── Views/
│   ├── StatusBarController.swift    # NSStatusItem + menu bar text/icon
│   ├── UsagePopover.swift           # Main popover with progress bars
│   ├── ProgressBarView.swift        # Reusable color-coded progress bar
│   ├── CountdownView.swift          # Live countdown timer component
│   └── SettingsView.swift           # Settings panel
├── Utilities/
│   └── TimeFormatter.swift          # "2h 14m", "Mon 2:00 PM" formatting
└── Assets.xcassets/                 # App icon, menu bar icons
```

---

## Configuration Storage

All preferences in `UserDefaults`:
- `pollInterval`: Int (seconds, default 60)
- `showFiveHourPercent`: Bool (default true)
- `showSevenDayPercent`: Bool (default true)
- `showCountdown`: Bool (default true)
- `showMiniBar`: Bool (default false)
- `showSonnet`: Bool (default true)
- `showOpus`: Bool (default true)
- `showCowork`: Bool (default false)
- `warningThreshold`: Int (default 70)
- `criticalThreshold`: Int (default 90)
- `launchAtLogin`: Bool (default false)
- `menuBarDisplayMode`: Enum (default/minimal/iconOnly)

---

## Distribution

- Xcode project → Archive → Export as `.dmg`
- Code sign with Developer ID for Gatekeeper
- No App Store (uses Keychain access that may not pass review)
- GitHub releases for distribution
