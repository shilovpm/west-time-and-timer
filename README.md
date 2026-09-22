# WEST time and timer

A small native macOS 15+ app with one deadline-based timer, a six-item world-clock list, and WidgetKit widgets. The approved violet interface follows the system light or dark appearance. Everything works offline.

## Local installation (no Apple Developer account)

The repository includes a locally ad-hoc-signed Apple Silicon build. Open [`dist/WEST-time-and-timer-local-arm64.dmg`](dist/WEST-time-and-timer-local-arm64.dmg), drag the app to Applications, and launch it. The app bundle includes the timer, clocks, WidgetKit extension, App Intents, localizations, and all runtime resources; users do not need Xcode, Homebrew, Swift, or any third-party dependency.

The local build is not Developer ID signed or notarized. On first launch after downloading it, macOS may require **System Settings → Privacy & Security → Open Anyway**. This approval is a Gatekeeper step for an unidentified developer, not a missing dependency. The current DMG requires macOS 15 or newer and an Apple Silicon Mac.

To rebuild the complete app and WidgetKit extension with the installed Xcode:

```bash
scripts/test-core.sh
scripts/build-xcode-local.sh
scripts/package-local-dmg.sh
```

`scripts/build-xcode-local.sh` makes a Release build without provisioning, verifies the generated App Intents metadata, and ad-hoc signs the app and extension for this Mac. The local build uses `~/Library/Application Support/WEST time and timer Shared` so the app and widget can share state without a registered App Group. `scripts/build-local.sh` remains a Command Line Tools fallback; its widgets do not contain configurable App Intents.

You can also open `WEST.xcodeproj`, select the shared `WEST` scheme, and Run. A distribution build with an Apple team should copy `Config/Signing.example.xcconfig`, use a registered App Group, and disable the local shared-storage switch.

## Features

- Cities and regional seasonal designations are independent records: Berlin and CET/CEST can coexist and be deleted separately.
- Automatic IANA rules for all entries; explicit regional rules for CET/CEST, EET/EEST, and WET/WEST.
- Search by city, country, IANA ID, abbreviation, or a current `UTC+02:00`-style offset.
- The clock row shows current time, current abbreviation, UTC offset, and the live difference from the Mac's current zone.
- One timer with 1-second through 23:59:59 durations, presets, pause/resume/reset/repeat, absolute-deadline recovery, and a local notification.
- World-clock widgets for small/medium/large and a small timer widget. Clock widgets mirror the saved order from the app; the timer has background App Intent controls.
- System light and dark appearances share the same layout, controls, symbols, and behavior; only the color palette changes.
- English, Simplified Chinese, Hindi, Spanish, Arabic, French, Bengali, Portuguese, Indonesian, Urdu, and Russian; Arabic and Urdu use RTL layout.
- Shared state is an atomically replaced Codable file protected by a stable BSD `flock` across the app and widget processes.

## Project map

- `WEST/Shared`: model, search catalog, persistence, commands, localization, and shared views.
- `WEST/App`: app UI and settings.
- `WEST/Widgets`: WidgetKit providers, views, configuration, and App Intent actions.
- `WESTTests`: deterministic DST, timer, corrupt-data, and interprocess checks.
- `Config`: local ad-hoc signing and optional distribution settings.
- `scripts`: deterministic project, catalog, test, build, and DMG helpers.

## Verification

See [`docs/VERIFICATION.md`](docs/VERIFICATION.md). On the current machine, the full Xcode build, 19 core checks, installed app, approved layout, time-zone rendering, extension signature and registration, App Intents metadata, and discovery of all four variants in the macOS widget gallery pass. The unresolved notification-banner icon and per-widget clock selection are documented follow-ups.

## Privacy

No accounts, analytics, network access, or server are used. The local-only build stores configured clocks, preferences, and timer state in a shared Application Support directory on this Mac. A team-signed distribution build uses its registered App Group container.
