# WEST time and timer 1.0.4-local

Requires macOS 15 or newer on Apple Silicon. This local build is ad-hoc signed and is not notarized.

The release DMG is arm64-only. Intel Macs, macOS 14 and older, iPhone, iPad, Windows, and Linux are not supported. Version 1.0.4 was built and verified on Apple Silicon with macOS 27.0. The app is self-contained and does not require Xcode, Homebrew, Swift, an Apple Developer account, or third-party dependencies.

1. Open `WEST-time-and-timer-local-arm64.dmg`.
2. Drag **WEST time and timer** to **Applications**.
3. Launch the app.
4. Add **World clocks** (small, medium, or large) and **Timer** (small) from the standard macOS widget gallery.

Included: one persistent timer, independent city/time-zone-designation records, up to six world clocks, automatic seasonal rules, difference relative to the Mac, 11 languages, and four WidgetKit variants. The local build uses ad-hoc signing and a local shared Application Support directory, so no Apple Developer account is required. The DMG contains the complete app and widget extension; users do not need Xcode, Swift, Homebrew, or other dependencies. Because the build is not Developer ID signed or notarized, the first downloaded launch may require **System Settings → Privacy & Security → Open Anyway**.

Version 1.0.4 fixes macOS 27 desktop widgets that remained light under the system dark appearance. Widget views now resolve the same approved palette from WidgetKit's own `colorScheme`, and the build number is incremented so macOS replaces cached extension views. Layout, icons, controls, data, and behavior are unchanged.

Known follow-ups: selecting a different saved-clock set for each widget and resolving the notification-banner icon are intentionally on hold.
